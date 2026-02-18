// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

/// <summary>
/// FactBox page that displays E-Document summary information when an E-Document is linked to a Purchase Invoice.
/// This page is designed to be embedded in the Purchase Invoice page.
/// </summary>
page 50025 "E-Doc. Linked FactBox"
{
    PageType = CardPart;
    UsageCategory = None;
    ApplicationArea = Basic, Suite;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    SourceTable = "E-Document";
    Caption = 'Linked E-Document';

    layout
    {
        area(Content)
        {
            group(EDocumentInfo)
            {
                ShowCaption = false;

                field("Entry No"; Rec."Entry No")
                {
                    Caption = 'Entry No.';
                    ToolTip = 'Specifies the entry number of the linked E-Document.';

                    trigger OnDrillDown()
                    begin
                        OpenEDocumentCard();
                    end;
                }
                field("Incoming E-Document No."; Rec."Incoming E-Document No.")
                {
                    Caption = 'E-Document No.';
                    ToolTip = 'Specifies the incoming E-Document number from the vendor.';
                }
                field("Amount Incl. VAT"; Rec."Amount Incl. VAT")
                {
                    Caption = 'Amount Incl. VAT';
                    ToolTip = 'Specifies the total amount including VAT from the E-Document.';
                }
                field(Status; Rec.Status)
                {
                    Caption = 'Status';
                    ToolTip = 'Specifies the status of the E-Document.';
                    StyleExpr = StatusStyleExpr;
                }
                field("Linked Invoice Match Type"; Rec."Linked Invoice Match Type")
                {
                    Caption = 'Match Type';
                    ToolTip = 'Specifies how this E-Document was matched to the Purchase Invoice.';
                }
                field("Linked At"; Rec."Linked At")
                {
                    Caption = 'Linked At';
                    ToolTip = 'Specifies when this E-Document was linked to the Purchase Invoice.';
                }
                field("Linked By"; Rec."Linked By")
                {
                    Caption = 'Linked By';
                    ToolTip = 'Specifies the user who linked this E-Document to the Purchase Invoice.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SetStatusStyle();
    end;

    local procedure SetStatusStyle()
    begin
        case Rec.Status of
            Rec.Status::Error:
                StatusStyleExpr := 'Unfavorable';
            Rec.Status::Processed:
                StatusStyleExpr := 'Favorable';
            else
                StatusStyleExpr := 'Standard';
        end;
    end;

    local procedure OpenEDocumentCard()
    var
        EDocumentPage: Page "E-Document";
    begin
        EDocumentPage.SetRecord(Rec);
        EDocumentPage.Run();
    end;

    /// <summary>
    /// Sets the E-Document record to display in the FactBox.
    /// </summary>
    /// <param name="EDocument">The E-Document record to display.</param>
    procedure SetEDocument(EDocument: Record "E-Document")
    begin
        if EDocument."Entry No" = 0 then begin
            Rec.Reset();
            CurrPage.Update(false);
            exit;
        end;

        Rec.Get(EDocument."Entry No");
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Sets the E-Document record to display by SystemId.
    /// </summary>
    /// <param name="EDocumentSystemId">The SystemId of the E-Document to display.</param>
    procedure SetEDocumentBySystemId(EDocumentSystemId: Guid)
    var
        EDocument: Record "E-Document";
    begin
        if IsNullGuid(EDocumentSystemId) then begin
            Clear(Rec);
            CurrPage.Update(false);
            exit;
        end;

        if EDocument.GetBySystemId(EDocumentSystemId) then begin
            Rec.Get(EDocument."Entry No");
            CurrPage.Update(false);
        end;
    end;

    var
        StatusStyleExpr: Text;
}
