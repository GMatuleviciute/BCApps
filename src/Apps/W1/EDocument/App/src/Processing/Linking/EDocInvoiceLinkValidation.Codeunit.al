// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.Purchases.Document;

codeunit 50012 "E-Doc. Invoice Link Validation"
{
    Access = Internal;

    var
        AmountFieldNameLbl: Label 'Amount Incl. VAT', Locked = true;
        VATAmountFieldNameLbl: Label 'VAT Amount', Locked = true;
        CurrencyFieldNameLbl: Label 'Currency Code', Locked = true;
        DateFieldNameLbl: Label 'Document Date', Locked = true;
        LinkedFieldNameLbl: Label 'E-Document Link', Locked = true;

    /// <summary>
    /// Validates the link between an E-Document and a Purchase Header, generating warnings for any discrepancies.
    /// </summary>
    /// <param name="EDocument">The E-Document to validate.</param>
    /// <param name="PurchaseHeader">The Purchase Header to validate against.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure ValidateLink(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        EDocumentService: Record "E-Document Service";
        TolerancePercent: Decimal;
        DateWindow: Integer;
    begin
        TempWarnings.Reset();
        TempWarnings.DeleteAll();

        // Get tolerance settings from service
        if EDocumentService.Get(EDocument.Service) then begin
            TolerancePercent := EDocumentService."Invoice Match Tolerance %";
            DateWindow := EDocumentService."Invoice Match Date Window";
        end else begin
            // Use defaults if service not found
            TolerancePercent := 0.5;
            DateWindow := 3;
        end;

        CheckAmountDiscrepancy(EDocument, PurchaseHeader, TolerancePercent, TempWarnings);
        CheckVATDiscrepancy(EDocument, PurchaseHeader, TolerancePercent, TempWarnings);
        CheckCurrencyMismatch(EDocument, PurchaseHeader, TempWarnings);
        CheckDateMismatch(EDocument, PurchaseHeader, DateWindow, TempWarnings);
        CheckExistingLink(PurchaseHeader, TempWarnings);
    end;

    /// <summary>
    /// Checks if there are any critical discrepancies (Error severity) in the warnings.
    /// </summary>
    /// <param name="TempWarnings">The warnings to check.</param>
    /// <returns>True if any Error severity warnings exist, false otherwise.</returns>
    procedure HasCriticalDiscrepancies(var TempWarnings: Record "E-Doc. Link Warning" temporary): Boolean
    begin
        TempWarnings.Reset();
        TempWarnings.SetRange(Severity, Enum::"E-Doc. Link Warning Severity"::Error);
        exit(not TempWarnings.IsEmpty());
    end;

    /// <summary>
    /// Gets the total count of warnings.
    /// </summary>
    /// <param name="TempWarnings">The warnings to count.</param>
    /// <returns>The number of warnings.</returns>
    procedure GetWarningCount(var TempWarnings: Record "E-Doc. Link Warning" temporary): Integer
    begin
        TempWarnings.Reset();
        exit(TempWarnings.Count());
    end;

    /// <summary>
    /// Checks for Amount Including VAT discrepancy between E-Document and Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <param name="PurchaseHeader">The Purchase Header to check against.</param>
    /// <param name="TolerancePercent">The tolerance percentage for amount matching.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure CheckAmountDiscrepancy(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; TolerancePercent: Decimal; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        EDocAmount: Decimal;
        PIAmount: Decimal;
        Variance: Decimal;
        ToleranceAmount: Decimal;
        Severity: Enum "E-Doc. Link Warning Severity";
    begin
        EDocAmount := EDocument."Amount Incl. VAT";
        PurchaseHeader.CalcFields("Amount Including VAT");
        PIAmount := PurchaseHeader."Amount Including VAT";

        Variance := PIAmount - EDocAmount;

        // No discrepancy
        if Variance = 0 then
            exit;

        // Determine severity based on tolerance
        if EDocAmount <> 0 then begin
            ToleranceAmount := Abs(EDocAmount * (TolerancePercent / 100));
            if Abs(Variance) <= ToleranceAmount then
                Severity := Enum::"E-Doc. Link Warning Severity"::Info
            else
                Severity := Enum::"E-Doc. Link Warning Severity"::Warning;
        end else
            Severity := Enum::"E-Doc. Link Warning Severity"::Warning;

        InsertWarning(
            TempWarnings,
            Enum::"E-Doc. Link Warning Type"::"Amount Mismatch",
            AmountFieldNameLbl,
            Format(EDocAmount, 0, '<Precision,2:2><Standard Format,0>'),
            Format(PIAmount, 0, '<Precision,2:2><Standard Format,0>'),
            Variance,
            Severity
        );
    end;

    /// <summary>
    /// Checks for VAT Amount discrepancy between E-Document and Purchase Invoice.
    /// VAT Amount is calculated as Amount Incl. VAT - Amount Excl. VAT.
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <param name="PurchaseHeader">The Purchase Header to check against.</param>
    /// <param name="TolerancePercent">The tolerance percentage for VAT matching.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure CheckVATDiscrepancy(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; TolerancePercent: Decimal; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        EDocVATAmount: Decimal;
        PIVATAmount: Decimal;
        Variance: Decimal;
        ToleranceAmount: Decimal;
        Severity: Enum "E-Doc. Link Warning Severity";
    begin
        // Calculate VAT amounts
        EDocVATAmount := EDocument."Amount Incl. VAT" - EDocument."Amount Excl. VAT";

        PurchaseHeader.CalcFields("Amount Including VAT");
        PurchaseHeader.CalcFields(Amount);
        PIVATAmount := PurchaseHeader."Amount Including VAT" - PurchaseHeader.Amount;

        Variance := PIVATAmount - EDocVATAmount;

        // No discrepancy
        if Variance = 0 then
            exit;

        // Determine severity based on tolerance
        if EDocVATAmount <> 0 then begin
            ToleranceAmount := Abs(EDocVATAmount * (TolerancePercent / 100));
            if Abs(Variance) <= ToleranceAmount then
                Severity := Enum::"E-Doc. Link Warning Severity"::Info
            else
                Severity := Enum::"E-Doc. Link Warning Severity"::Warning;
        end else
            if Abs(Variance) > 0.01 then // Allow minor rounding differences
                Severity := Enum::"E-Doc. Link Warning Severity"::Warning
            else
                exit; // Ignore tiny rounding differences

        InsertWarning(
            TempWarnings,
            Enum::"E-Doc. Link Warning Type"::"VAT Mismatch",
            VATAmountFieldNameLbl,
            Format(EDocVATAmount, 0, '<Precision,2:2><Standard Format,0>'),
            Format(PIVATAmount, 0, '<Precision,2:2><Standard Format,0>'),
            Variance,
            Severity
        );
    end;

    /// <summary>
    /// Checks for Currency Code mismatch between E-Document and Purchase Invoice.
    /// Currency mismatch is always treated as an Error (critical discrepancy).
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <param name="PurchaseHeader">The Purchase Header to check against.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure CheckCurrencyMismatch(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        EDocCurrency: Code[10];
        PICurrency: Code[10];
    begin
        EDocCurrency := EDocument."Currency Code";
        PICurrency := PurchaseHeader."Currency Code";

        // No mismatch
        if EDocCurrency = PICurrency then
            exit;

        InsertWarning(
            TempWarnings,
            Enum::"E-Doc. Link Warning Type"::"Currency Mismatch",
            CurrencyFieldNameLbl,
            EDocCurrency,
            PICurrency,
            0,
            Enum::"E-Doc. Link Warning Severity"::Error
        );
    end;

    /// <summary>
    /// Checks for Document Date mismatch between E-Document and Purchase Invoice.
    /// </summary>
    /// <param name="EDocument">The E-Document to check.</param>
    /// <param name="PurchaseHeader">The Purchase Header to check against.</param>
    /// <param name="DateWindow">The allowed date window in days.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure CheckDateMismatch(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; DateWindow: Integer; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        EDocDate: Date;
        PIDate: Date;
        DateDiff: Integer;
        Severity: Enum "E-Doc. Link Warning Severity";
    begin
        EDocDate := EDocument."Document Date";
        PIDate := PurchaseHeader."Document Date";

        // Handle missing dates
        if (EDocDate = 0D) or (PIDate = 0D) then
            exit;

        DateDiff := PIDate - EDocDate;

        // No mismatch
        if DateDiff = 0 then
            exit;

        // Determine severity based on date window
        if Abs(DateDiff) <= DateWindow then
            Severity := Enum::"E-Doc. Link Warning Severity"::Info
        else
            Severity := Enum::"E-Doc. Link Warning Severity"::Warning;

        InsertWarning(
            TempWarnings,
            Enum::"E-Doc. Link Warning Type"::"Date Mismatch",
            DateFieldNameLbl,
            Format(EDocDate),
            Format(PIDate),
            DateDiff,
            Severity
        );
    end;

    /// <summary>
    /// Checks if the Purchase Invoice is already linked to another E-Document.
    /// </summary>
    /// <param name="PurchaseHeader">The Purchase Header to check.</param>
    /// <param name="TempWarnings">The temporary table to populate with warnings.</param>
    procedure CheckExistingLink(PurchaseHeader: Record "Purchase Header"; var TempWarnings: Record "E-Doc. Link Warning" temporary)
    var
        LinkedEDocument: Record "E-Document";
        LinkedEDocInfo: Text[100];
    begin
        if IsNullGuid(PurchaseHeader."E-Document Link") then
            exit;

        // Find the linked E-Document to provide context
        LinkedEDocument.SetRange(SystemId, PurchaseHeader."E-Document Link");
        if LinkedEDocument.FindFirst() then
            LinkedEDocInfo := Format(LinkedEDocument."Entry No") + ' - ' + LinkedEDocument."Incoming E-Document No."
        else
            LinkedEDocInfo := Format(PurchaseHeader."E-Document Link");

        InsertWarning(
            TempWarnings,
            Enum::"E-Doc. Link Warning Type"::"Already Linked",
            LinkedFieldNameLbl,
            '',
            LinkedEDocInfo,
            0,
            Enum::"E-Doc. Link Warning Severity"::Warning
        );
    end;

    local procedure InsertWarning(var TempWarnings: Record "E-Doc. Link Warning" temporary; WarningType: Enum "E-Doc. Link Warning Type"; FieldName: Text[50]; EDocValue: Text[100]; PIValue: Text[100]; Variance: Decimal; Severity: Enum "E-Doc. Link Warning Severity")
    var
        NextEntryNo: Integer;
    begin
        TempWarnings.Reset();
        if TempWarnings.FindLast() then
            NextEntryNo := TempWarnings."Entry No." + 1
        else
            NextEntryNo := 1;

        TempWarnings.Init();
        TempWarnings."Entry No." := NextEntryNo;
        TempWarnings."Warning Type" := WarningType;
        TempWarnings."Field Name" := FieldName;
        TempWarnings."E-Document Value" := EDocValue;
        TempWarnings."Purchase Invoice Value" := PIValue;
        TempWarnings.Variance := Variance;
        TempWarnings.Severity := Severity;
        TempWarnings.Insert();
    end;
}
