// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

page 50020 "E-Doc. Invoice Matches"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Invoice Matches';
    SourceTable = "E-Doc. Invoice Match Buffer";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Matches)
            {
                ShowCaption = false;
                field("Match Type"; Rec."Match Type")
                {
                    StyleExpr = MatchTypeStyleExpr;
                    ToolTip = 'Specifies the type of match: Exact, Strong, Fallback, or Manual.';
                }
                field("Document No."; Rec."Document No.")
                {
                    StyleExpr = MatchTypeStyleExpr;
                    ToolTip = 'Specifies the document number of the purchase invoice.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the vendor number.';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ToolTip = 'Specifies the name of the vendor.';
                }
                field("Vendor Invoice No."; Rec."Vendor Invoice No.")
                {
                    ToolTip = 'Specifies the vendor''s invoice number.';
                }
                field("Amount Including VAT"; Rec."Amount Including VAT")
                {
                    ToolTip = 'Specifies the total amount including VAT.';
                }
                field("Document Date"; Rec."Document Date")
                {
                    ToolTip = 'Specifies the date of the document.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ToolTip = 'Specifies the currency code of the document.';
                }
                field("Already Linked"; Rec."Already Linked")
                {
                    StyleExpr = AlreadyLinkedStyleExpr;
                    ToolTip = 'Specifies whether this purchase invoice is already linked to another e-document.';
                }
            }
        }
    }

    var
        MatchTypeStyleExpr: Text;
        AlreadyLinkedStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        UpdateStyleExpressions();
    end;

    local procedure UpdateStyleExpressions()
    begin
        // Set style based on Match Type
        case Rec."Match Type" of
            Rec."Match Type"::Exact:
                MatchTypeStyleExpr := 'Favorable';
            Rec."Match Type"::Strong:
                MatchTypeStyleExpr := 'Strong';
            Rec."Match Type"::Fallback:
                MatchTypeStyleExpr := 'Ambiguous';
            Rec."Match Type"::Manual:
                MatchTypeStyleExpr := 'StrongAccent';
            else
                MatchTypeStyleExpr := 'Standard';
        end;

        // Highlight already linked invoices
        if Rec."Already Linked" then
            AlreadyLinkedStyleExpr := 'Attention'
        else
            AlreadyLinkedStyleExpr := 'Standard';
    end;

    /// <summary>
    /// Sets the match buffer records to display in the list.
    /// </summary>
    /// <param name="TempMatchBuffer">The temporary match buffer records to display.</param>
    procedure SetMatchBuffer(var TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if TempMatchBuffer.FindSet() then
            repeat
                Rec.TransferFields(TempMatchBuffer);
                Rec.Insert();
            until TempMatchBuffer.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Gets the currently selected match record.
    /// </summary>
    /// <param name="SelectedMatch">Returns the selected match buffer record.</param>
    /// <returns>True if a record is selected, false otherwise.</returns>
    procedure GetSelectedMatch(var SelectedMatch: Record "E-Doc. Invoice Match Buffer" temporary): Boolean
    begin
        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindFirst() then begin
            SelectedMatch.TransferFields(Rec);
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Gets all selected match records.
    /// </summary>
    /// <param name="TempSelectedMatches">Returns the selected match buffer records.</param>
    procedure GetSelectedMatches(var TempSelectedMatches: Record "E-Doc. Invoice Match Buffer" temporary)
    begin
        TempSelectedMatches.Reset();
        TempSelectedMatches.DeleteAll();

        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                TempSelectedMatches.TransferFields(Rec);
                TempSelectedMatches.Insert();
            until Rec.Next() = 0;
    end;

    /// <summary>
    /// Checks if a match is currently selected.
    /// </summary>
    /// <returns>True if at least one match is selected.</returns>
    procedure HasSelection(): Boolean
    begin
        CurrPage.SetSelectionFilter(Rec);
        exit(not Rec.IsEmpty());
    end;
}
