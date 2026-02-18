// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Purchases.Document;

using Microsoft.eServices.EDocument;

/// <summary>
/// Page extension for Purchase Invoice that enables linking to an E-Document.
/// This extension adds:
/// - E-Document FactBox showing linked E-Document details
/// - Action to link an E-Document from the Inbound E-Documents list
/// - Action to view the linked E-Document card
/// </summary>
pageextension 50024 "Purch. Invoice E-Doc Link" extends "Purchase Invoice"
{
    layout
    {
        addfirst(FactBoxes)
        {
            part(EDocLinkedFactBox; "E-Doc. Linked FactBox")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Linked E-Document';
                Visible = HasLinkedEDocument;
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        addlast("E-Document")
        {
            action(LinkEDocument)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Link E-Document';
                ToolTip = 'Link this Purchase Invoice to an existing inbound E-Document.';
                Image = LinkAccount;
                Visible = not HasLinkedEDocument;

                trigger OnAction()
                begin
                    LinkSelectedEDocument();
                end;
            }
            action(ViewEDocument)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'View E-Document';
                ToolTip = 'Open the linked E-Document card.';
                Image = ViewDetails;
                Visible = HasLinkedEDocument;

                trigger OnAction()
                begin
                    ViewLinkedEDocument();
                end;
            }
            action(UnlinkEDocument)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Unlink E-Document';
                ToolTip = 'Remove the link between this Purchase Invoice and the E-Document.';
                Image = UnLinkAccount;
                Visible = HasLinkedEDocument;

                trigger OnAction()
                begin
                    UnlinkFromEDocument();
                end;
            }
        }
        addlast("E-Document Promoted")
        {
            actionref(LinkEDocument_Promoted; LinkEDocument)
            {
            }
            actionref(ViewEDocument_Promoted; ViewEDocument)
            {
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        UpdateEDocumentLinkStatus();
    end;

    local procedure UpdateEDocumentLinkStatus()
    begin
        HasLinkedEDocument := not IsNullGuid(Rec."E-Document Link");

        if HasLinkedEDocument then
            UpdateFactBox();
    end;

    local procedure UpdateFactBox()
    begin
        CurrPage.EDocLinkedFactBox.Page.SetEDocumentBySystemId(Rec."E-Document Link");
    end;

    local procedure LinkSelectedEDocument()
    var
        EDocument: Record "E-Document";
        PurchaseHeader: Record "Purchase Header";
        EDocInvoiceLinking: Codeunit "E-Doc. Invoice Linking";
        InboundEDocuments: Page "Inbound E-Documents";
    begin
        // Filter to only show unlinked incoming E-Documents
        EDocument.SetRange(Direction, EDocument.Direction::Incoming);
        EDocument.SetFilter(Status, '<>%1', EDocument.Status::Processed);

        InboundEDocuments.SetTableView(EDocument);
        InboundEDocuments.LookupMode(true);

        if InboundEDocuments.RunModal() <> Action::LookupOK then
            exit;

        InboundEDocuments.GetRecord(EDocument);

        // Validate the E-Document can be linked
        if not EDocInvoiceLinking.CanLink(EDocument) then begin
            Message(CannotLinkEDocMsg);
            exit;
        end;

        // Get this Purchase Invoice as Purchase Header
        PurchaseHeader.Get(Rec."Document Type", Rec."No.");

        // Perform the link with Manual match type
        EDocInvoiceLinking.LinkToInvoice(EDocument, PurchaseHeader, Enum::"E-Doc. Invoice Match Type"::Manual);

        // Refresh the record to show the link
        CurrPage.Update(false);
        Message(EDocLinkedMsg, EDocument."Entry No");
    end;

    local procedure ViewLinkedEDocument()
    var
        EDocument: Record "E-Document";
        EDocumentPage: Page "E-Document";
    begin
        if not EDocument.GetBySystemId(Rec."E-Document Link") then begin
            Message(EDocNotFoundMsg);
            exit;
        end;

        EDocumentPage.SetRecord(EDocument);
        EDocumentPage.Run();
    end;

    local procedure UnlinkFromEDocument()
    var
        EDocument: Record "E-Document";
        EDocInvoiceLinking: Codeunit "E-Doc. Invoice Linking";
    begin
        if not EDocument.GetBySystemId(Rec."E-Document Link") then begin
            Message(EDocNotFoundMsg);
            exit;
        end;

        if not EDocInvoiceLinking.CanUnlink(EDocument) then begin
            Message(CannotUnlinkEDocMsg);
            exit;
        end;

        if not Confirm(ConfirmUnlinkQst, false, EDocument."Entry No") then
            exit;

        EDocInvoiceLinking.UnlinkFromInvoice(EDocument);

        CurrPage.Update(false);
        Message(EDocUnlinkedMsg);
    end;

    var
        HasLinkedEDocument: Boolean;
        CannotLinkEDocMsg: Label 'The selected E-Document cannot be linked to this Purchase Invoice. It may already be linked or processed.';
        CannotUnlinkEDocMsg: Label 'The E-Document cannot be unlinked. It may already be processed or the Purchase Invoice has been posted.';
        EDocLinkedMsg: Label 'E-Document %1 has been linked to this Purchase Invoice.', Comment = '%1 = E-Document Entry No';
        EDocUnlinkedMsg: Label 'The E-Document has been unlinked from this Purchase Invoice.';
        EDocNotFoundMsg: Label 'The linked E-Document could not be found.';
        ConfirmUnlinkQst: Label 'Are you sure you want to unlink E-Document %1 from this Purchase Invoice?', Comment = '%1 = E-Document Entry No';
}
