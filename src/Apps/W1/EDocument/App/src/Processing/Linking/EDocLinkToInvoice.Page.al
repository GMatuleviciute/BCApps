// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.Purchases.Document;

/// <summary>
/// Link to Invoice wizard page for E-Documents.
/// Allows users to select a Purchase Invoice to link to an E-Document.
/// </summary>
/// <remarks>
/// Step 1: Select a Purchase Invoice from the list of matches
/// Step 2: Review any validation warnings
/// Step 3: Provide override reason if the PI is already linked
/// </remarks>
page 50023 "E-Doc. Link to Invoice"
{
    Caption = 'Link E-Document to Purchase Invoice';
    PageType = NavigatePage;

    layout
    {
        area(Content)
        {
            // Step 1: E-Document Information Header
            group(EDocumentInfoGroup)
            {
                Caption = 'E-Document Information';
                Visible = Step1Visible;

                field(EDocEntryNo; GlobalEDocument."Entry No")
                {
                    ApplicationArea = All;
                    Caption = 'Entry No.';
                    Editable = false;
                    ToolTip = 'Specifies the entry number of the e-document.';
                }
                field(EDocIncomingNo; GlobalEDocument."Incoming E-Document No.")
                {
                    ApplicationArea = All;
                    Caption = 'Incoming E-Document No.';
                    Editable = false;
                    ToolTip = 'Specifies the incoming e-document number.';
                }
                field(EDocVendorNo; GlobalEDocument."Bill-to/Pay-to No.")
                {
                    ApplicationArea = All;
                    Caption = 'Vendor No.';
                    Editable = false;
                    ToolTip = 'Specifies the vendor number from the e-document.';
                }
                field(EDocAmount; GlobalEDocument."Amount Incl. VAT")
                {
                    ApplicationArea = All;
                    Caption = 'Amount Incl. VAT';
                    Editable = false;
                    ToolTip = 'Specifies the amount including VAT from the e-document.';
                }
            }

            // Step 1: Select Invoice
            group(Step1Group)
            {
                Caption = 'Step 1: Select Purchase Invoice';
                Visible = Step1Visible;
                InstructionalText = 'Select a Purchase Invoice to link to this E-Document. Matches are ranked by quality: Exact (best), Strong, Fallback.';

                part(InvoiceMatchesPart; "E-Doc. Invoice Matches")
                {
                    ApplicationArea = All;
                    Caption = 'Matching Purchase Invoices';
                }
            }
            group(NoMatchesGroup)
            {
                Caption = 'No Matches Found';
                Visible = Step1Visible and NoMatchesFound;
                InstructionalText = 'No matching Purchase Invoices were found for this E-Document. You can create a new Purchase Invoice manually or close this wizard.';
            }

            // Step 2: Review Warnings
            group(Step2Group)
            {
                Caption = 'Step 2: Review Warnings';
                Visible = Step2Visible;
                InstructionalText = 'The following discrepancies were detected between the E-Document and the selected Purchase Invoice. Review them before proceeding.';

                part(LinkWarningsPart; "E-Doc. Link Warnings")
                {
                    ApplicationArea = All;
                    Caption = 'Validation Warnings';
                }
            }
            group(NoWarningsGroup)
            {
                Caption = 'No Warnings';
                Visible = Step2Visible and NoWarningsFound;
                InstructionalText = 'No discrepancies were detected between the E-Document and the selected Purchase Invoice. You can proceed to link them.';
            }
            group(WarningsSummaryGroup)
            {
                Caption = 'Summary';
                Visible = Step2Visible and (not NoWarningsFound);

                field(WarningCountField; WarningCountText)
                {
                    ApplicationArea = All;
                    Caption = 'Total Warnings';
                    Editable = false;
                    ToolTip = 'Specifies the total number of warnings found.';
                    Style = Attention;
                    StyleExpr = HasCriticalWarnings;
                }
                field(CriticalWarningField; CriticalWarningText)
                {
                    ApplicationArea = All;
                    Caption = 'Critical Warnings';
                    Editable = false;
                    Visible = HasCriticalWarnings;
                    ToolTip = 'Specifies that there are critical warnings that may prevent linking.';
                    Style = Unfavorable;
                }
            }

            // Step 3: Override Reason (only shown if PI already linked)
            group(Step3Group)
            {
                Caption = 'Step 3: Override Existing Link';
                Visible = Step3Visible;
                InstructionalText = 'The selected Purchase Invoice is already linked to another E-Document. Please provide a reason for overriding the existing link.';

                field(LinkedEDocInfo; LinkedEDocInfoText)
                {
                    ApplicationArea = All;
                    Caption = 'Currently Linked To';
                    Editable = false;
                    ToolTip = 'Specifies the E-Document currently linked to the selected Purchase Invoice.';
                    Style = Attention;
                }
                field(OverrideReasonField; OverrideReason)
                {
                    ApplicationArea = All;
                    Caption = 'Override Reason';
                    ToolTip = 'Specifies the reason for overriding the existing link. This field is mandatory.';
                    MultiLine = true;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        UpdateControls();
                    end;
                }
            }

            // Step 3: Confirmation (when no override needed)
            group(Step3ConfirmGroup)
            {
                Caption = 'Step 3: Confirm Link';
                Visible = Step3Visible and (not RequiresOverride);
                InstructionalText = 'You are about to link the E-Document to the selected Purchase Invoice. Click Finish to complete the operation.';

                field(SelectedInvoiceNo; SelectedInvoiceNo)
                {
                    ApplicationArea = All;
                    Caption = 'Selected Invoice';
                    Editable = false;
                    ToolTip = 'Specifies the Purchase Invoice that will be linked.';
                }
                field(MatchTypeField; SelectedMatchTypeText)
                {
                    ApplicationArea = All;
                    Caption = 'Match Type';
                    Editable = false;
                    ToolTip = 'Specifies the type of match for the selected invoice.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionBack)
            {
                Caption = 'Back';
                Image = PreviousRecord;
                ToolTip = 'Go to the previous step.';
                InFooterBar = true;
                Enabled = BackEnabled;

                trigger OnAction()
                begin
                    TakeStep(-1);
                end;
            }
            action(ActionNext)
            {
                Caption = 'Next';
                Image = NextRecord;
                ToolTip = 'Go to the next step.';
                InFooterBar = true;
                Enabled = NextEnabled;

                trigger OnAction()
                begin
                    if ValidateCurrentStep() then
                        TakeStep(1);
                end;
            }
            action(ActionFinish)
            {
                Caption = 'Finish';
                Image = Approve;
                ToolTip = 'Link the E-Document to the selected Purchase Invoice.';
                InFooterBar = true;
                Enabled = FinishEnabled;

                trigger OnAction()
                begin
                    FinishWizard();
                end;
            }
        }
    }

    var
        GlobalEDocument: Record "E-Document";
        TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary;
        TempSelectedMatch: Record "E-Doc. Invoice Match Buffer" temporary;
        TempWarnings: Record "E-Doc. Link Warning" temporary;
        CurrentStep: Integer;
        TotalSteps: Integer;
        BackEnabled: Boolean;
        NextEnabled: Boolean;
        FinishEnabled: Boolean;
        Step1Visible: Boolean;
        Step2Visible: Boolean;
        Step3Visible: Boolean;
        NoMatchesFound: Boolean;
        NoWarningsFound: Boolean;
        HasCriticalWarnings: Boolean;
        RequiresOverride: Boolean;
        WarningCountText: Text;
        CriticalWarningText: Text;
        LinkedEDocInfoText: Text;
        OverrideReason: Text[250];
        SelectedInvoiceNo: Code[20];
        SelectedMatchTypeText: Text;
        SelectInvoiceErr: Label 'Please select a Purchase Invoice to link.';
        OverrideReasonRequiredErr: Label 'You must provide a reason for overriding the existing link.';
        CriticalWarningsErr: Label 'Cannot proceed due to critical warnings. The currency code must match between the E-Document and Purchase Invoice.';
        LinkSuccessMsg: Label 'E-Document %1 has been successfully linked to Purchase Invoice %2.', Comment = '%1 = E-Document Entry No, %2 = Purchase Invoice No.';

    trigger OnOpenPage()
    begin
        CurrentStep := 1;
        TotalSteps := 3;
        InitializePage();
        UpdateControls();
    end;

    /// <summary>
    /// Sets the E-Document to link.
    /// </summary>
    /// <param name="EDocument">The E-Document record.</param>
    internal procedure SetEDocument(EDocument: Record "E-Document")
    begin
        GlobalEDocument := EDocument;
    end;

    /// <summary>
    /// Sets the match buffer containing potential Purchase Invoice matches.
    /// </summary>
    /// <param name="NewTempMatchBuffer">The temporary match buffer.</param>
    internal procedure SetMatchBuffer(var NewTempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary)
    begin
        TempMatchBuffer.Reset();
        TempMatchBuffer.DeleteAll();
        if NewTempMatchBuffer.FindSet() then
            repeat
                TempMatchBuffer := NewTempMatchBuffer;
                TempMatchBuffer.Insert();
            until NewTempMatchBuffer.Next() = 0;
    end;

    local procedure InitializePage()
    begin
        // Initialize the matches part with data
        CurrPage.InvoiceMatchesPart.Page.SetMatchBuffer(TempMatchBuffer);

        // Check if there are any matches
        TempMatchBuffer.Reset();
        NoMatchesFound := TempMatchBuffer.IsEmpty();
    end;

    local procedure TakeStep(Step: Integer)
    begin
        CurrentStep += Step;

        // When moving to step 2, validate selection and get warnings
        if (CurrentStep = 2) and (Step > 0) then
            PrepareStep2();

        // When moving to step 3, prepare confirmation or override
        if (CurrentStep = 3) and (Step > 0) then
            PrepareStep3();

        UpdateControls();
    end;

    local procedure ValidateCurrentStep(): Boolean
    begin
        case CurrentStep of
            1:
                exit(ValidateStep1());
            2:
                exit(ValidateStep2());
            else
                exit(true);
        end;
    end;

    local procedure ValidateStep1(): Boolean
    begin
        // Check that an invoice is selected
        if not CurrPage.InvoiceMatchesPart.Page.GetSelectedMatch(TempSelectedMatch) then begin
            Error(SelectInvoiceErr);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateStep2(): Boolean
    begin
        // Check for critical warnings (currency mismatch)
        if HasCriticalWarnings then begin
            Error(CriticalWarningsErr);
            exit(false);
        end;
        exit(true);
    end;

    local procedure PrepareStep2()
    var
        PurchaseHeader: Record "Purchase Header";
        EDocLinkValidation: Codeunit "E-Doc. Invoice Link Validation";
        InfoCount: Integer;
        WarningCount: Integer;
        ErrorCount: Integer;
    begin
        // Get the selected match
        if not CurrPage.InvoiceMatchesPart.Page.GetSelectedMatch(TempSelectedMatch) then
            exit;

        // Find the Purchase Header
        if not PurchaseHeader.GetBySystemId(TempSelectedMatch."Purchase Header SystemId") then
            exit;

        // Validate and get warnings
        TempWarnings.Reset();
        TempWarnings.DeleteAll();
        EDocLinkValidation.ValidateLink(GlobalEDocument, PurchaseHeader, TempWarnings);

        // Update the warnings part
        CurrPage.LinkWarningsPart.Page.SetWarnings(TempWarnings);

        // Get warning counts
        CurrPage.LinkWarningsPart.Page.GetWarningCounts(InfoCount, WarningCount, ErrorCount);

        // Update UI state
        NoWarningsFound := not CurrPage.LinkWarningsPart.Page.HasWarnings();
        HasCriticalWarnings := CurrPage.LinkWarningsPart.Page.HasCriticalWarnings();

        // Build summary texts
        WarningCountText := Format(CurrPage.LinkWarningsPart.Page.GetWarningCount());
        if HasCriticalWarnings then
            CriticalWarningText := StrSubstNo('%1 critical error(s) that must be resolved', ErrorCount);

        // Check if override is required
        RequiresOverride := TempSelectedMatch."Already Linked";
    end;

    local procedure PrepareStep3()
    var
        LinkedEDocument: Record "E-Document";
    begin
        // Get selected invoice info for confirmation
        SelectedInvoiceNo := TempSelectedMatch."Document No.";
        SelectedMatchTypeText := Format(TempSelectedMatch."Match Type");

        // If already linked, get info about the linked E-Document
        if TempSelectedMatch."Already Linked" then begin
            if LinkedEDocument.Get(TempSelectedMatch."Linked E-Document Entry No") then
                LinkedEDocInfoText := StrSubstNo('E-Document %1 - %2', LinkedEDocument."Entry No", LinkedEDocument."Incoming E-Document No.")
            else
                LinkedEDocInfoText := StrSubstNo('E-Document Entry No. %1', TempSelectedMatch."Linked E-Document Entry No");
        end;
    end;

    local procedure UpdateControls()
    begin
        // Step visibility
        Step1Visible := CurrentStep = 1;
        Step2Visible := CurrentStep = 2;
        Step3Visible := CurrentStep = 3;

        // Navigation buttons
        BackEnabled := CurrentStep > 1;
        NextEnabled := (CurrentStep < TotalSteps) and (not NoMatchesFound);
        FinishEnabled := (CurrentStep = TotalSteps) and CanFinish();
    end;

    local procedure CanFinish(): Boolean
    begin
        // Cannot finish if no match selected
        if TempSelectedMatch."Entry No." = 0 then
            exit(false);

        // Cannot finish if override required but no reason provided
        if RequiresOverride and (OverrideReason = '') then
            exit(false);

        // Cannot finish if there are critical warnings
        if HasCriticalWarnings then
            exit(false);

        exit(true);
    end;

    local procedure FinishWizard()
    var
        PurchaseHeader: Record "Purchase Header";
        EDocInvoiceLinking: Codeunit "E-Doc. Invoice Linking";
    begin
        // Validate override reason if required
        if RequiresOverride and (OverrideReason = '') then
            Error(OverrideReasonRequiredErr);

        // Get the Purchase Header
        if not PurchaseHeader.GetBySystemId(TempSelectedMatch."Purchase Header SystemId") then
            exit;

        // Perform the linking operation
        if RequiresOverride then
            EDocInvoiceLinking.RelinkToInvoice(GlobalEDocument, PurchaseHeader, OverrideReason)
        else
            EDocInvoiceLinking.LinkToInvoice(GlobalEDocument, PurchaseHeader, TempSelectedMatch."Match Type");

        Message(LinkSuccessMsg, GlobalEDocument."Entry No", PurchaseHeader."No.");
        CurrPage.Close();
    end;
}
