// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.Purchases.Document;
using System.Telemetry;

codeunit 50011 "E-Doc. Invoice Linking"
{
    Access = Internal;
    Permissions =
        tabledata "E-Document" = rm,
        tabledata "E-Document Log" = rim,
        tabledata "E-Document Service Status" = rm,
        tabledata "Purchase Header" = rm;

    var
        FeatureTelemetryNameTok: Label 'E-Document Invoice Linking', Locked = true;
        LinkedTelemetryTok: Label 'E-Document linked to Purchase Invoice', Locked = true;
        UnlinkedTelemetryTok: Label 'E-Document unlinked from Purchase Invoice', Locked = true;
        RelinkedTelemetryTok: Label 'E-Document relinked to different Purchase Invoice', Locked = true;
        AutoSuggestTelemetryTok: Label 'Auto-suggest found match for E-Document', Locked = true;
        CannotLinkProcessedErr: Label 'Cannot link E-Document %1 because it has already been processed.', Comment = '%1 = E-Document Entry No';
        CannotLinkAlreadyLinkedErr: Label 'Cannot link E-Document %1 because it is already linked to a document.', Comment = '%1 = E-Document Entry No';
        CannotLinkOutgoingErr: Label 'Cannot link E-Document %1 because it is an outgoing document.', Comment = '%1 = E-Document Entry No';
        CannotUnlinkNotLinkedErr: Label 'Cannot unlink E-Document %1 because it is not linked to any Purchase Invoice.', Comment = '%1 = E-Document Entry No';
        CannotUnlinkPostedErr: Label 'Cannot unlink E-Document %1 because the linked Purchase Invoice has been posted.', Comment = '%1 = E-Document Entry No';
        PurchaseInvoiceNotFoundErr: Label 'The Purchase Invoice could not be found.';

    #region Public API

    /// <summary>
    /// Checks if an E-Document can be linked to a Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <returns>True if the E-Document can be linked, false otherwise.</returns>
    procedure CanLink(EDocument: Record "E-Document"): Boolean
    begin
        // Must be incoming document
        if EDocument.Direction <> EDocument.Direction::Incoming then
            exit(false);

        // Must not have a Document Record ID (not already processed to create a document)
        if EDocument."Document Record ID".TableNo <> 0 then
            exit(false);

        // Must not be already processed (status check)
        if EDocument.Status = EDocument.Status::Processed then
            exit(false);

        // Check if already linked to a Purchase Invoice by looking for Invoice Linked status
        if IsInvoiceLinked(EDocument) then
            exit(false);

        exit(true);
    end;

    /// <summary>
    /// Checks if an E-Document can be unlinked from a Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <returns>True if the E-Document can be unlinked, false otherwise.</returns>
    procedure CanUnlink(EDocument: Record "E-Document"): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        // Must be linked
        if not IsInvoiceLinked(EDocument) then
            exit(false);

        // Find the linked Purchase Invoice
        if not FindLinkedPurchaseHeader(EDocument, PurchaseHeader) then
            exit(false);

        // PI must not be posted (Purchase Header still exists means not posted)
        // If we found it, it's not posted
        exit(true);
    end;

    /// <summary>
    /// Links an E-Document to a Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to link.</param>
    /// <param name="PurchaseHeader">The Purchase Invoice to link to.</param>
    /// <param name="MatchType">The type of match that was used.</param>
    procedure LinkToInvoice(var EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; MatchType: Enum "E-Doc. Invoice Match Type")
    var
        Telemetry: Codeunit Telemetry;
    begin
        ValidateCanLink(EDocument);

        // Update E-Document fields
        UpdateEDocumentLinkFields(EDocument, MatchType, '');

        // Update Purchase Header link
        UpdatePurchaseHeaderLink(PurchaseHeader, EDocument.SystemId);

        // Update E-Document service status
        UpdateEDocumentServiceStatus(EDocument);

        // Log the action
        LogInvoiceLinkAction(EDocument, Enum::"E-Doc. Link Action"::Linked, GetEmptyGuid(), '');

        Telemetry.LogMessage('0000EIL', LinkedTelemetryTok, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All);
    end;

    /// <summary>
    /// Unlinks an E-Document from its linked Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to unlink.</param>
    procedure UnlinkFromInvoice(var EDocument: Record "E-Document")
    var
        PurchaseHeader: Record "Purchase Header";
        PreviousLink: Guid;
        Telemetry: Codeunit Telemetry;
    begin
        ValidateCanUnlink(EDocument);

        // Get the current link for logging
        if FindLinkedPurchaseHeader(EDocument, PurchaseHeader) then begin
            PreviousLink := PurchaseHeader."E-Document Link";

            // Clear Purchase Header link
            ClearPurchaseHeaderLink(PurchaseHeader);
        end;

        // Clear E-Document fields
        ClearEDocumentLinkFields(EDocument);

        // Update status back to pending
        RevertEDocumentServiceStatus(EDocument);

        // Log the action
        LogInvoiceLinkAction(EDocument, Enum::"E-Doc. Link Action"::Unlinked, PreviousLink, '');

        Telemetry.LogMessage('0000EIU', UnlinkedTelemetryTok, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All);
    end;

    /// <summary>
    /// Relinks an E-Document to a different Purchase Invoice, requiring an override reason.
    /// </summary>
    /// <param name="EDocument">The E-Document to relink.</param>
    /// <param name="NewPurchaseHeader">The new Purchase Invoice to link to.</param>
    /// <param name="OverrideReason">The reason for overriding the existing link.</param>
    procedure RelinkToInvoice(var EDocument: Record "E-Document"; NewPurchaseHeader: Record "Purchase Header"; OverrideReason: Text[250])
    var
        OldPurchaseHeader: Record "Purchase Header";
        PreviousLink: Guid;
        Telemetry: Codeunit Telemetry;
    begin
        // First, capture the old link
        if FindLinkedPurchaseHeader(EDocument, OldPurchaseHeader) then begin
            PreviousLink := OldPurchaseHeader."E-Document Link";
            ClearPurchaseHeaderLink(OldPurchaseHeader);
        end;

        // Update E-Document fields with override reason
        UpdateEDocumentLinkFields(EDocument, Enum::"E-Doc. Invoice Match Type"::Manual, OverrideReason);

        // Update new Purchase Header link
        UpdatePurchaseHeaderLink(NewPurchaseHeader, EDocument.SystemId);

        // Update E-Document service status
        UpdateEDocumentServiceStatus(EDocument);

        // Log the action with previous link and reason
        LogInvoiceLinkAction(EDocument, Enum::"E-Doc. Link Action"::Relinked, PreviousLink, OverrideReason);

        Telemetry.LogMessage('0000EIR', RelinkedTelemetryTok, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All);
    end;

    /// <summary>
    /// Attempts to find and suggest a match for the E-Document automatically.
    /// </summary>
    /// <param name="EDocument">The E-Document to find a match for.</param>
    /// <returns>True if a match was found and suggested, false otherwise.</returns>
    procedure TrySuggestMatch(var EDocument: Record "E-Document"): Boolean
    var
        TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary;
        PurchaseHeader: Record "Purchase Header";
        EDocInvoiceMatcher: Codeunit "E-Doc. Invoice Matcher";
        Telemetry: Codeunit Telemetry;
        MatchType: Enum "E-Doc. Invoice Match Type";
    begin
        if not CanLink(EDocument) then
            exit(false);

        // Find potential matches
        EDocInvoiceMatcher.FindMatches(EDocument, TempMatchBuffer);

        // Get the best match
        if not EDocInvoiceMatcher.GetBestMatch(TempMatchBuffer) then
            exit(false);

        // Only auto-link for Exact or Strong matches
        MatchType := TempMatchBuffer."Match Type";
        if not (MatchType in [Enum::"E-Doc. Invoice Match Type"::Exact, Enum::"E-Doc. Invoice Match Type"::Strong]) then
            exit(false);

        // Skip if already linked to another E-Document
        if TempMatchBuffer."Already Linked" then
            exit(false);

        // Get the Purchase Header
        if not PurchaseHeader.GetBySystemId(TempMatchBuffer."Purchase Header SystemId") then
            exit(false);

        // Perform the link
        LinkToInvoice(EDocument, PurchaseHeader, MatchType);

        Telemetry.LogMessage('0000EIA', AutoSuggestTelemetryTok, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All);
        exit(true);
    end;

    #endregion

    #region Wizard Entry Points

    /// <summary>
    /// Opens the Link to Invoice wizard for the E-Document.
    /// </summary>
    /// <param name="EDocument">The E-Document to link.</param>
    procedure RunLinkToInvoiceWizard(var EDocument: Record "E-Document")
    var
        TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary;
        EDocInvoiceMatcher: Codeunit "E-Doc. Invoice Matcher";
        EDocLinkToInvoice: Page "E-Doc. Link to Invoice";
    begin
        ValidateCanLink(EDocument);

        // Find potential matches
        EDocInvoiceMatcher.FindMatches(EDocument, TempMatchBuffer);

        // Open the wizard page with the E-Document and matches
        EDocLinkToInvoice.SetEDocument(EDocument);
        EDocLinkToInvoice.SetMatchBuffer(TempMatchBuffer);
        EDocLinkToInvoice.RunModal();

        // Refresh the E-Document to get any changes made by the wizard
        EDocument.Get(EDocument."Entry No");
    end;

    /// <summary>
    /// Runs the unlink wizard/confirmation for the E-Document.
    /// </summary>
    /// <param name="EDocument">The E-Document to unlink.</param>
    procedure RunUnlinkWizard(var EDocument: Record "E-Document")
    var
        PurchaseHeader: Record "Purchase Header";
        ConfirmUnlinkQst: Label 'Are you sure you want to unlink E-Document %1 from Purchase Invoice %2?', Comment = '%1 = E-Document Entry No, %2 = Purchase Invoice No.';
        ConfirmUnlinkSimpleQst: Label 'Are you sure you want to unlink this E-Document from the Purchase Invoice?';
    begin
        ValidateCanUnlink(EDocument);

        if FindLinkedPurchaseHeader(EDocument, PurchaseHeader) then begin
            if not Confirm(ConfirmUnlinkQst, false, EDocument."Entry No", PurchaseHeader."No.") then
                exit;
        end else
            if not Confirm(ConfirmUnlinkSimpleQst) then
                exit;

        UnlinkFromInvoice(EDocument);
    end;

    #endregion

    #region Internal Operations

    local procedure ValidateCanLink(EDocument: Record "E-Document")
    begin
        if EDocument.Direction <> EDocument.Direction::Incoming then
            Error(CannotLinkOutgoingErr, EDocument."Entry No");

        if EDocument."Document Record ID".TableNo <> 0 then
            Error(CannotLinkAlreadyLinkedErr, EDocument."Entry No");

        if EDocument.Status = EDocument.Status::Processed then
            Error(CannotLinkProcessedErr, EDocument."Entry No");

        if IsInvoiceLinked(EDocument) then
            Error(CannotLinkAlreadyLinkedErr, EDocument."Entry No");
    end;

    local procedure ValidateCanUnlink(EDocument: Record "E-Document")
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        if not IsInvoiceLinked(EDocument) then
            Error(CannotUnlinkNotLinkedErr, EDocument."Entry No");

        if not FindLinkedPurchaseHeader(EDocument, PurchaseHeader) then
            Error(CannotUnlinkPostedErr, EDocument."Entry No");
    end;

    local procedure IsInvoiceLinked(EDocument: Record "E-Document"): Boolean
    var
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.SetRange(Status, Enum::"E-Document Service Status"::"Invoice Linked");
        exit(not EDocumentServiceStatus.IsEmpty());
    end;

    local procedure FindLinkedPurchaseHeader(EDocument: Record "E-Document"; var PurchaseHeader: Record "Purchase Header"): Boolean
    begin
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseHeader.SetRange("E-Document Link", EDocument.SystemId);
        exit(PurchaseHeader.FindFirst());
    end;

    local procedure UpdateEDocumentLinkFields(var EDocument: Record "E-Document"; MatchType: Enum "E-Doc. Invoice Match Type"; OverrideReason: Text[250])
    begin
        EDocument."Linked Invoice Match Type" := MatchType;
        EDocument."Link Override Reason" := OverrideReason;
        EDocument."Linked By" := CopyStr(UserId(), 1, MaxStrLen(EDocument."Linked By"));
        EDocument."Linked At" := CurrentDateTime();
        EDocument.Modify(true);
    end;

    local procedure ClearEDocumentLinkFields(var EDocument: Record "E-Document")
    begin
        EDocument."Linked Invoice Match Type" := Enum::"E-Doc. Invoice Match Type"::" ";
        EDocument."Link Override Reason" := '';
        EDocument."Linked By" := '';
        EDocument."Linked At" := 0DT;
        EDocument.Modify(true);
    end;

    local procedure UpdatePurchaseHeaderLink(var PurchaseHeader: Record "Purchase Header"; EDocumentSystemId: Guid)
    begin
        PurchaseHeader."E-Document Link" := EDocumentSystemId;
        PurchaseHeader.Modify(true);
    end;

    local procedure ClearPurchaseHeaderLink(var PurchaseHeader: Record "Purchase Header")
    begin
        Clear(PurchaseHeader."E-Document Link");
        PurchaseHeader.Modify(true);
    end;

    local procedure UpdateEDocumentServiceStatus(EDocument: Record "E-Document")
    var
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        if EDocumentServiceStatus.FindFirst() then begin
            EDocumentServiceStatus.Validate(Status, Enum::"E-Document Service Status"::"Invoice Linked");
            EDocumentServiceStatus.Modify(true);
        end;
    end;

    local procedure RevertEDocumentServiceStatus(EDocument: Record "E-Document")
    var
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        if EDocumentServiceStatus.FindFirst() then begin
            // Revert to Pending status
            EDocumentServiceStatus.Validate(Status, Enum::"E-Document Service Status"::Pending);
            EDocumentServiceStatus.Modify(true);
        end;
    end;

    local procedure LogInvoiceLinkAction(EDocument: Record "E-Document"; LinkAction: Enum "E-Doc. Link Action"; PreviousLink: Guid; OverrideReason: Text[250])
    var
        EDocumentLog: Record "E-Document Log";
        EDocumentService: Record "E-Document Service";
    begin
        if EDocumentService.Get(EDocument.Service) then;

        EDocumentLog.Init();
        EDocumentLog.Validate("Document Type", EDocument."Document Type");
        EDocumentLog.Validate("Document No.", EDocument."Document No.");
        EDocumentLog.Validate("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.Validate(Status, Enum::"E-Document Service Status"::"Invoice Linked");
        EDocumentLog.Validate("Service Code", EDocumentService.Code);
        EDocumentLog.Validate("Service Integration V2", EDocumentService."Service Integration V2");
        EDocumentLog.Validate("Document Format", EDocumentService."Document Format");
        EDocumentLog.Validate("Link Action", LinkAction);
        EDocumentLog.Validate("Previous E-Document Link", PreviousLink);
        EDocumentLog.Validate("Override Reason", OverrideReason);
        EDocumentLog.Insert(true);
    end;

    local procedure GetEmptyGuid(): Guid
    var
        EmptyGuid: Guid;
    begin
        exit(EmptyGuid);
    end;

    #endregion
}
