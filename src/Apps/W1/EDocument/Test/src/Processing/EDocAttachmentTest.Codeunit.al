// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument.Test;

using Microsoft.eServices.EDocument;
using Microsoft.eServices.EDocument.Integration;
using Microsoft.Finance.Currency;
using Microsoft.eServices.EDocument.Processing.Import;
using Microsoft.Foundation.Attachment;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Sales.History;
using System.IO;
using System.TestLibraries.Utilities;
using System.Utilities;

codeunit 139889 "E-Doc. Attachment Test"
{
    Subtype = Test;
    TestType = IntegrationTest;

    var
        Customer: Record Customer;
        EDocumentService: Record "E-Document Service";
        Assert: Codeunit Assert;
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryEDoc: Codeunit "Library - E-Document";
        LibraryJobQueue: Codeunit "Library - Job Queue";
        EDocImplState: Codeunit "E-Doc. Impl. State";
        LibraryLowerPermission: Codeunit "Library - Lower Permissions";
        IsInitialized: Boolean;
        IncorrectValueErr: Label 'Incorrect value found';

    [Test]
    procedure ExportSalesInvoiceWithAttachment()
    var
        EDocument: Record "E-Document";
        SalesInvHeader: Record "Sales Invoice Header";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
    begin
        // [FEATURE] [E-Document] [Export] [Attachment]
        // [SCENARIO] When posting a sales invoice with "Attach Sales E-Document" enabled,
        // the exported e-document file should be attached to the posted sales invoice

        // [GIVEN] E-Document service with "Attach Sales E-Document" enabled
        Initialize(Enum::"Service Integration"::"Mock");
        EDocumentService."Attach Sales E-Document" := true;
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [WHEN] Post a sales invoice
        LibraryJobQueue.SetDoNotHandleCodeunitJobQueueEnqueueEvent(true);
        SalesInvHeader := LibraryEDoc.PostInvoice(Customer);

        // [THEN] E-Document is created
        EDocument.SetRange("Document No.", SalesInvHeader."No.");
        EDocument.FindFirst();
        Assert.AreEqual(SalesInvHeader."No.", EDocument."Document No.", IncorrectValueErr);

        // [THEN] Incoming Document Attachment is created for the sales invoice
        IncomingDocumentAttachment.SetRange("Document No.", SalesInvHeader."No.");
        IncomingDocumentAttachment.SetRange("Posting Date", SalesInvHeader."Posting Date");
        IncomingDocumentAttachment.SetRange("Is E-Document", true);
        Assert.RecordIsNotEmpty(IncomingDocumentAttachment);

        // [THEN] The attachment has content
        IncomingDocumentAttachment.FindFirst();
        IncomingDocumentAttachment.CalcFields(Content);
        Assert.IsTrue(IncomingDocumentAttachment.Content.HasValue(), 'Incoming Document Attachment should have content');
    end;

    [Test]
    procedure ExportSalesInvoiceWithoutAttachment()
    var
        EDocument: Record "E-Document";
        SalesInvHeader: Record "Sales Invoice Header";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
    begin
        // [FEATURE] [E-Document] [Export] [Attachment]
        // [SCENARIO] When posting a sales invoice with "Attach Sales E-Document" disabled,
        // no attachment should be created

        // [GIVEN] E-Document service with "Attach Sales E-Document" disabled
        Initialize(Enum::"Service Integration"::"Mock");
        EDocumentService."Attach Sales E-Document" := false;
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [WHEN] Post a sales invoice
        LibraryJobQueue.SetDoNotHandleCodeunitJobQueueEnqueueEvent(true);
        SalesInvHeader := LibraryEDoc.PostInvoice(Customer);

        // [THEN] E-Document is created
        EDocument.SetRange("Document No.", SalesInvHeader."No.");
        EDocument.FindFirst();
        Assert.AreEqual(SalesInvHeader."No.", EDocument."Document No.", IncorrectValueErr);

        // [THEN] No Incoming Document Attachment is created for the sales invoice with E-Document flag
        IncomingDocumentAttachment.SetRange("Document No.", SalesInvHeader."No.");
        IncomingDocumentAttachment.SetRange("Posting Date", SalesInvHeader."Posting Date");
        IncomingDocumentAttachment.SetRange("Is E-Document", true);
        Assert.RecordIsEmpty(IncomingDocumentAttachment);
    end;

    [Test]
    procedure ImportPurchaseInvoiceWithAttachment()
    var
        EDocument: Record "E-Document";
        PurchaseHeader: Record "Purchase Header";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        EDocImportParams: Record "E-Doc. Import Parameters";
    begin
        // [FEATURE] [E-Document] [Import] [Attachment]
        // [SCENARIO] When importing an e-document and finishing the draft to create a purchase invoice,
        // the original e-document file should be attached to the purchase invoice as an incoming document

        // [GIVEN] E-Document service configured for import with Version 2.0
        Initialize(Enum::"Service Integration"::"Mock");
        EDocumentService."Read into Draft Impl." := "E-Doc. Read into Draft"::PEPPOL;
        EDocumentService."Import Process" := "E-Document Import Process"::"Version 2.0";
        this.EDocumentService.Modify(false);

        // [GIVEN] Work date is set to process the PEPPOL invoice (document date is in 2026)
        WorkDate(DMY2Date(1, 1, 2027));

        // [GIVEN] An inbound e-document with PEPPOL format processed to draft ready state
        EDocImportParams."Step to Run" := "Import E-Document Steps"::"Finish draft";
        Assert.IsTrue(LibraryEDoc.CreateInboundPEPPOLDocumentToState(EDocument, EDocumentService, 'peppol/peppol-invoice-0.xml', EDocImportParams), 'The e-document should be processed');

        // [THEN] E-Document should be created
        EDocument.Get(EDocument."Entry No");
        Assert.AreNotEqual(0, EDocument."Entry No", 'E-Document should be created');

        // [THEN] Purchase Invoice should be created
        PurchaseHeader.Get(EDocument."Document Record ID");

        // [THEN] Purchase Header has an Incoming Document Entry No. set
        Assert.AreNotEqual(0, PurchaseHeader."Incoming Document Entry No.", 'Purchase Header should have an Incoming Document Entry No.');

        // [THEN] Incoming Document Attachment is created for the purchase invoice and marked as E-Document
        IncomingDocumentAttachment.SetRange("Incoming Document Entry No.", PurchaseHeader."Incoming Document Entry No.");
        IncomingDocumentAttachment.SetRange("Is E-Document", true);
        Assert.RecordIsNotEmpty(IncomingDocumentAttachment);

        // [THEN] The attachment has content
        IncomingDocumentAttachment.FindFirst();
        IncomingDocumentAttachment.CalcFields(Content);
        Assert.IsTrue(IncomingDocumentAttachment.Content.HasValue(), 'Incoming Document Attachment should have content');
    end;

    local procedure Initialize(Integration: Enum "Service Integration")
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentSetup: Record "E-Documents Setup";
        Vendor: Record Vendor;
        Currency: Record Currency;
        LibraryERM: Codeunit "Library - ERM";
        Date: Date;
    begin
        LibraryLowerPermission.SetOutsideO365Scope();
        LibraryVariableStorage.Clear();
        Clear(EDocImplState);

        if IsInitialized then
            exit;

        EDocument.DeleteAll();
        EDocumentServiceStatus.DeleteAll();
        EDocumentService.DeleteAll();

        LibraryEDoc.SetupStandardVAT();
        LibraryEDoc.SetupStandardSalesScenario(Customer, EDocumentService, Enum::"E-Document Format"::Mock, Integration);
        LibraryEDoc.SetupStandardPurchaseScenario(Vendor, EDocumentService, Enum::"E-Document Format"::Mock, Integration);
        EDocumentService.Modify();
        EDocumentSetup.InsertNewExperienceSetup();

        Currency.Init();
        Currency.Validate(Code, 'XYZ');
        if Currency.Insert(true) then begin
            Date := DWY2Date(1, 1, 2025); // Ensure date is before any documents that are loaded in the tests.
            LibraryERM.CreateExchangeRate(Currency.Code, Date, 1.0, 1.0);
        end;

        IsInitialized := true;
    end;
}
