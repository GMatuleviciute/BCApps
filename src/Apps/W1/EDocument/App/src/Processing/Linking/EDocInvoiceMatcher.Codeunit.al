// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

codeunit 50010 "E-Doc. Invoice Matcher"
{
    Access = Internal;

    var
        // Scoring constants
        InvoiceNumberMatchScore: Integer;
        AmountExactMatchScore: Integer;
        AmountWithinToleranceScore: Integer;
        CurrencyMatchScore: Integer;
        DateExactMatchScore: Integer;
        DateWithinWindowScore: Integer;
        // Match type thresholds
        ExactMatchThreshold: Integer;
        StrongMatchThreshold: Integer;
        FallbackMatchThreshold: Integer;

    local procedure InitializeScoring()
    begin
        // Scoring breakdown per technical design
        InvoiceNumberMatchScore := 100;
        AmountExactMatchScore := 50;
        AmountWithinToleranceScore := 30;
        CurrencyMatchScore := 20;
        DateExactMatchScore := 30;
        DateWithinWindowScore := 15;

        // Match type thresholds
        ExactMatchThreshold := 200;
        StrongMatchThreshold := 130;
        FallbackMatchThreshold := 100;
    end;

    /// <summary>
    /// Finds matching Purchase Invoices for the given E-Document and populates the match buffer.
    /// </summary>
    /// <param name="EDocument">The E-Document to find matches for.</param>
    /// <param name="TempMatchBuffer">The temporary buffer to populate with matches.</param>
    procedure FindMatches(EDocument: Record "E-Document"; var TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary)
    var
        EDocumentService: Record "E-Document Service";
        PurchaseHeader: Record "Purchase Header";
        VendorNo: Code[20];
        EntryNo: Integer;
        Score: Integer;
        MatchType: Enum "E-Doc. Invoice Match Type";
    begin
        InitializeScoring();
        TempMatchBuffer.Reset();
        TempMatchBuffer.DeleteAll();

        // Step 1: Resolve vendor
        if not ResolveVendor(EDocument, VendorNo) then
            exit; // No vendor match possible

        // Step 2: Get tolerance settings
        if EDocumentService.Get(EDocument.Service) then;

        // Step 3: Find candidate Purchase Invoices
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseHeader.SetRange("Buy-from Vendor No.", VendorNo);
        if not PurchaseHeader.FindSet() then
            exit;

        // Step 4: Score each candidate
        EntryNo := 0;
        repeat
            // Invoice number is required for a match
            if MatchesInvoiceNumber(EDocument, PurchaseHeader) then begin
                Score := GetMatchScore(EDocument, PurchaseHeader);

                if Score >= FallbackMatchThreshold then begin
                    MatchType := ClassifyMatch(Score);
                    EntryNo += 1;
                    InsertMatchBuffer(TempMatchBuffer, EntryNo, PurchaseHeader, Score, MatchType);
                end;
            end;
        until PurchaseHeader.Next() = 0;

        // Step 5: Sort by score descending
        TempMatchBuffer.SetCurrentKey("Match Score");
        TempMatchBuffer.Ascending(false);
    end;

    /// <summary>
    /// Gets the best match from the match buffer.
    /// </summary>
    /// <param name="TempMatchBuffer">The match buffer to find the best match from.</param>
    /// <returns>True if a match was found, false otherwise.</returns>
    procedure GetBestMatch(var TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary): Boolean
    begin
        TempMatchBuffer.SetCurrentKey("Match Score");
        TempMatchBuffer.Ascending(false);
        exit(TempMatchBuffer.FindFirst());
    end;

    /// <summary>
    /// Calculates the match score between an E-Document and a Purchase Header.
    /// </summary>
    /// <param name="EDocument">The E-Document to match.</param>
    /// <param name="PurchaseHeader">The Purchase Header to match against.</param>
    /// <returns>The calculated match score.</returns>
    procedure GetMatchScore(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"): Integer
    var
        EDocumentService: Record "E-Document Service";
        Score: Integer;
        TolerancePercent: Decimal;
        DateWindow: Integer;
    begin
        InitializeScoring();
        Score := 0;

        // Get tolerance settings from service
        if EDocumentService.Get(EDocument.Service) then begin
            TolerancePercent := EDocumentService."Invoice Match Tolerance %";
            DateWindow := EDocumentService."Invoice Match Date Window";
        end else begin
            // Use defaults if service not found
            TolerancePercent := 0.5;
            DateWindow := 3;
        end;

        // Invoice Number (required) - Must be checked before calling this function
        if MatchesInvoiceNumber(EDocument, PurchaseHeader) then
            Score += InvoiceNumberMatchScore
        else
            exit(0); // No match without invoice number

        // Amount matching
        Score += GetAmountScore(EDocument, PurchaseHeader, TolerancePercent);

        // Currency matching
        if MatchesCurrency(EDocument, PurchaseHeader) then
            Score += CurrencyMatchScore;

        // Date matching
        Score += GetDateScore(EDocument, PurchaseHeader, DateWindow);

        exit(Score);
    end;

    /// <summary>
    /// Classifies the match type based on the score.
    /// </summary>
    /// <param name="Score">The match score to classify.</param>
    /// <returns>The classified match type.</returns>
    procedure ClassifyMatch(Score: Integer): Enum "E-Doc. Invoice Match Type"
    begin
        InitializeScoring();

        case true of
            Score >= ExactMatchThreshold:
                exit(Enum::"E-Doc. Invoice Match Type"::Exact);
            Score >= StrongMatchThreshold:
                exit(Enum::"E-Doc. Invoice Match Type"::Strong);
            Score >= FallbackMatchThreshold:
                exit(Enum::"E-Doc. Invoice Match Type"::Fallback);
            else
                exit(Enum::"E-Doc. Invoice Match Type"::" ");
        end;
    end;

    /// <summary>
    /// Resolves the vendor from the E-Document using GLN first, then VAT number, then direct match.
    /// </summary>
    /// <param name="EDocument">The E-Document containing vendor identification.</param>
    /// <param name="VendorNo">The resolved vendor number.</param>
    /// <returns>True if vendor was resolved, false otherwise.</returns>
    procedure ResolveVendor(EDocument: Record "E-Document"; var VendorNo: Code[20]): Boolean
    var
        Vendor: Record Vendor;
    begin
        VendorNo := '';

        // Try GLN first (most reliable)
        if EDocument."Receiving Company GLN" <> '' then
            if ResolveVendorByGLN(EDocument."Receiving Company GLN", Vendor) then begin
                VendorNo := Vendor."No.";
                exit(true);
            end;

        // Fallback to VAT Registration No.
        if EDocument."Receiving Company VAT Reg. No." <> '' then
            if ResolveVendorByVAT(EDocument."Receiving Company VAT Reg. No.", Vendor) then begin
                VendorNo := Vendor."No.";
                exit(true);
            end;

        // Direct match on Bill-to/Pay-to No.
        if EDocument."Bill-to/Pay-to No." <> '' then
            if Vendor.Get(EDocument."Bill-to/Pay-to No.") then begin
                VendorNo := Vendor."No.";
                exit(true);
            end;

        exit(false);
    end;

    /// <summary>
    /// Resolves a vendor by GLN (Global Location Number).
    /// </summary>
    /// <param name="GLN">The GLN to search for.</param>
    /// <param name="Vendor">The found vendor record.</param>
    /// <returns>True if vendor was found, false otherwise.</returns>
    procedure ResolveVendorByGLN(GLN: Code[13]; var Vendor: Record Vendor): Boolean
    begin
        if GLN = '' then
            exit(false);

        Vendor.SetRange(GLN, GLN);
        exit(Vendor.FindFirst());
    end;

    /// <summary>
    /// Resolves a vendor by VAT Registration Number.
    /// </summary>
    /// <param name="VATNo">The VAT number to search for.</param>
    /// <param name="Vendor">The found vendor record.</param>
    /// <returns>True if vendor was found, false otherwise.</returns>
    procedure ResolveVendorByVAT(VATNo: Text[20]; var Vendor: Record Vendor): Boolean
    begin
        if VATNo = '' then
            exit(false);

        Vendor.SetRange("VAT Registration No.", VATNo);
        exit(Vendor.FindFirst());
    end;

    local procedure MatchesInvoiceNumber(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"): Boolean
    begin
        if EDocument."Incoming E-Document No." = '' then
            exit(false);
        if PurchaseHeader."Vendor Invoice No." = '' then
            exit(false);
        exit(UpperCase(PurchaseHeader."Vendor Invoice No.") = UpperCase(EDocument."Incoming E-Document No."));
    end;

    local procedure MatchesCurrency(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"): Boolean
    begin
        exit(PurchaseHeader."Currency Code" = EDocument."Currency Code");
    end;

    local procedure GetAmountScore(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; TolerancePercent: Decimal): Integer
    var
        EDocAmount: Decimal;
        PIAmount: Decimal;
        AmountVariance: Decimal;
        ToleranceAmount: Decimal;
    begin
        EDocAmount := EDocument."Amount Incl. VAT";
        PurchaseHeader.CalcFields("Amount Including VAT");
        PIAmount := PurchaseHeader."Amount Including VAT";

        AmountVariance := Abs(PIAmount - EDocAmount);

        // Exact match
        if AmountVariance = 0 then
            exit(AmountExactMatchScore);

        // Within tolerance
        if EDocAmount <> 0 then begin
            ToleranceAmount := Abs(EDocAmount * (TolerancePercent / 100));
            if AmountVariance <= ToleranceAmount then
                exit(AmountWithinToleranceScore);
        end;

        exit(0);
    end;

    local procedure GetDateScore(EDocument: Record "E-Document"; PurchaseHeader: Record "Purchase Header"; DateWindow: Integer): Integer
    var
        DateDiff: Integer;
    begin
        if (EDocument."Document Date" = 0D) or (PurchaseHeader."Document Date" = 0D) then
            exit(0);

        DateDiff := Abs(PurchaseHeader."Document Date" - EDocument."Document Date");

        // Exact date match
        if DateDiff = 0 then
            exit(DateExactMatchScore);

        // Within date window
        if DateDiff <= DateWindow then
            exit(DateWithinWindowScore);

        exit(0);
    end;

    local procedure InsertMatchBuffer(var TempMatchBuffer: Record "E-Doc. Invoice Match Buffer" temporary; EntryNo: Integer; PurchaseHeader: Record "Purchase Header"; Score: Integer; MatchType: Enum "E-Doc. Invoice Match Type")
    var
        Vendor: Record Vendor;
        LinkedEDocument: Record "E-Document";
    begin
        TempMatchBuffer.Init();
        TempMatchBuffer."Entry No." := EntryNo;
        TempMatchBuffer."Purchase Header SystemId" := PurchaseHeader.SystemId;
        TempMatchBuffer."Document No." := PurchaseHeader."No.";
        TempMatchBuffer."Vendor No." := PurchaseHeader."Buy-from Vendor No.";
        if Vendor.Get(PurchaseHeader."Buy-from Vendor No.") then
            TempMatchBuffer."Vendor Name" := Vendor.Name;
        TempMatchBuffer."Vendor Invoice No." := PurchaseHeader."Vendor Invoice No.";
        PurchaseHeader.CalcFields("Amount Including VAT");
        TempMatchBuffer."Amount Including VAT" := PurchaseHeader."Amount Including VAT";
        TempMatchBuffer."Document Date" := PurchaseHeader."Document Date";
        TempMatchBuffer."Currency Code" := PurchaseHeader."Currency Code";
        TempMatchBuffer."Match Score" := Score;
        TempMatchBuffer."Match Type" := MatchType;

        // Check if already linked
        if not IsNullGuid(PurchaseHeader."E-Document Link") then begin
            TempMatchBuffer."Already Linked" := true;
            LinkedEDocument.SetRange(SystemId, PurchaseHeader."E-Document Link");
            if LinkedEDocument.FindFirst() then
                TempMatchBuffer."Linked E-Document Entry No" := LinkedEDocument."Entry No";
        end;

        TempMatchBuffer.Insert();
    end;
}
