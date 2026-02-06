// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.eServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using System.IO;
using System.Utilities;


codeunit 6169 "E-Doc. Attachment Processor"
{
    Permissions = tabledata "Document Attachment" = rimd;

    /// <summary>
    /// Move attachments from E-Document to NewDocument. Clean up any attachments stored on EDocument.
    /// </summary>
    internal procedure MoveAttachmentsAndDelete(EDocument: Record "E-Document"; NewDocument: RecordId)
    var
        RecordRefTo: RecordRef;
    begin
        if (EDocument.Direction = Enum::"E-Document Direction"::Incoming) and
            (EDocument."Document Type" <> Enum::"E-Document Type"::"General Journal") then begin
            RecordRefTo.Get(NewDocument);
            MoveToPurchaseDocument(EDocument, RecordRefTo);
            RecordRefTo.GetTable(EDocument);
            DeleteAll(EDocument, RecordRefTo);
        end;
    end;

    /// <summary>
    /// Insert Document Attachment record from stream and filename
    /// Framework moves E-Document attachments to created documents at the end of import process
    /// </summary>
    procedure Insert(EDocument: Record "E-Document"; DocStream: InStream; FileName: Text)
    var
        DocumentAttachment: Record "Document Attachment";
        RecordRef: RecordRef;
    begin
        RecordRef.GetTable(EDocument);
        DocumentAttachment.SaveAttachmentFromStream(DocStream, RecordRef, FileName);
        DocumentAttachment."Document Flow Purchase" := true;
        DocumentAttachment.Validate("E-Document Attachment", true);
        DocumentAttachment.Validate("E-Document Entry No.", EDocument."Entry No");
        DocumentAttachment.Modify();
    end;

    /// <summary>
    /// Delete all document attachments for EDocument or purchase header
    /// </summary>
    /// <param name="EDocument">E-Document that attachment should be related to through "E-Document Entry No."</param>
    /// <param name="RecordRef">Document header. Supports E-document and Purchase Header</param>
    internal procedure DeleteAll(EDocument: Record "E-Document"; RecordRef: RecordRef)
    var
        DocumentAttachment: Record "Document Attachment";
        PurchaseHeader: Record "Purchase Header";
    begin
        case RecordRef.Number() of
            Database::"E-Document":
                DocumentAttachment.SetRange("No.", RecordRef.Field(EDocument.FieldNo("Entry No")).Value);
            Database::"Purchase Header":
                begin
                    DocumentAttachment.SetRange("No.", RecordRef.Field(PurchaseHeader.FieldNo("No.")).Value);
                    DocumentAttachment.SetRange("Document Type", RecordRef.Field(PurchaseHeader.FieldNo("Document Type")).Value);
                end;
        end;
        DocumentAttachment.SetRange("Table ID", RecordRef.Number());
        DocumentAttachment.SetRange("E-Document Attachment", true);
        DocumentAttachment.SetRange("E-Document Entry No.", EDocument."Entry No");
        DocumentAttachment.DeleteAll();
    end;

    /// <summary>
    /// Move attachment from E-Document to the newly created document.
    /// Used when importing E-Document into BC Document.
    /// </summary>
    local procedure MoveToPurchaseDocument(EDocument: Record "E-Document"; RecordRef: RecordRef)
    var
        DocumentAttachment, DocumentAttachment2 : Record "Document Attachment";
        DocumentType: Enum "Attachment Document Type";
        DocumentNo: Code[20];
        UnrecognizedTableForPurchaseDocumentErr: Label 'Unrecognized table for e-document''s purchase document attachment';
    begin
        DocumentAttachment.SetRange("Table ID", Database::"E-Document");
        DocumentAttachment.SetRange("No.", Format(EDocument."Entry No"));
#pragma warning disable AA0210
        DocumentAttachment.SetRange("E-Document Attachment", true);
#pragma warning restore AA0210
        if DocumentAttachment.IsEmpty() then
            exit;

        case EDocument."Document Type" of
            "E-Document Type"::"Purchase Credit Memo":
                DocumentType := DocumentType::"Credit Memo";
            "E-Document Type"::"Purchase Invoice":
                DocumentType := DocumentType::Invoice;
            "E-Document Type"::"Purchase Order":
                DocumentType := DocumentType::Order;
            "E-Document Type"::"Purchase Quote":
                DocumentType := DocumentType::Quote;
            "E-Document Type"::"Purchase Return Order":
                DocumentType := DocumentType::"Return Order";
            else
                Error(MissingEDocumentTypeErr, EDocument."Document Type");
        end;
        if not (RecordRef.Number() in [Database::"Purchase Header", Database::"Purch. Inv. Header"]) then
            Error(UnrecognizedTableForPurchaseDocumentErr);

        DocumentNo := RecordRef.Field(3).Value(); // "No." for both Purchase Header and Purchase Invoice Header

        DocumentAttachment.FindSet();
        repeat
            DocumentAttachment2 := DocumentAttachment;
            DocumentAttachment2.Rename(RecordRef.Number(), DocumentNo, DocumentType, 0, DocumentAttachment2.ID);
        until DocumentAttachment.Next() = 0;
    end;

    local procedure ExtractXMLFromPDF(var TempBlob: Codeunit System.Utilities."Temp Blob"; FileName: Text; var IncomingDocumentAttachment: Record "Incoming Document Attachment")
    var
        PDFDocument: Codeunit "PDF Document";
        ImportAttachmentIncDoc: Codeunit "Import Attachment - Inc. Doc.";
        ExtractedXmlBlob: Codeunit "Temp Blob";
        PdfInStream: InStream;
    begin
        TempBlob.CreateInStream(PdfInStream);
        if not PDFDocument.GetDocumentAttachmentStream(PdfInStream, ExtractedXmlBlob) then
            exit;

        if not ExtractedXmlBlob.HasValue() then
            exit;

        IncomingDocumentAttachment.Default := false;
        IncomingDocumentAttachment."Main Attachment" := false;
        if not ImportAttachmentIncDoc.ImportAttachment(IncomingDocumentAttachment, FileName, ExtractedXmlBlob) then
            exit;

        IncomingDocumentAttachment."Is E-Document" := true;
        IncomingDocumentAttachment.Modify(false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Document Attachment Mgmt", OnCopyAttachmentsOnAfterSetFromParameters, '', false, false)]
    local procedure OnCopyAttachmentsOnAfterSetFromParameters(FromRecRef: RecordRef; var FromDocumentAttachment: Record "Document Attachment"; var FromAttachmentDocumentType: Enum "Attachment Document Type")
    var
        EDocument: Record "E-Document";
    begin
        if FromRecRef.Number() <> Database::"E-Document" then
            exit;

        EDocument := FromRecRef;
        FromDocumentAttachment.SetRange("No.", Format(EDocument."Entry No"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Document Attachment Mgmt", OnAfterTableHasNumberFieldPrimaryKey, '', false, false)]
    local procedure OnAfterTableHasNumberFieldPrimaryKeyForEDocs(TableNo: Integer; var Result: Boolean; var FieldNo: Integer)
    var
        EDocument: Record "E-Document";
    begin
        case TableNo of
            Database::"E-Document":
                begin
                    FieldNo := EDocument.FieldNo("Entry No");
                    Result := true;
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Document Attachment Mgmt", OnAfterSetDocumentAttachmentFiltersForRecRef, '', false, false)]
    local procedure OnAfterSetDocumentAttachmentFiltersForRecRef(var DocumentAttachment: Record "Document Attachment"; RecRef: RecordRef)
    begin
        case RecRef.Number() of
            Database::"E-Document":
                DocumentAttachment.SetRange("E-Document Attachment", true);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Document Attachment Mgmt", OnAfterGetRefTable, '', false, false)]
    local procedure OnAfterGetRefTableForEDocs(var RecRef: RecordRef; DocumentAttachment: Record "Document Attachment")
    var
        EDocument: Record "E-Document";
    begin
        case DocumentAttachment."Table ID" of
            Database::"E-Document":
                begin
                    RecRef.Open(Database::"E-Document");
                    if EDocument.Get(DocumentAttachment."No.") then
                        RecRef.GetTable(EDocument);
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Doc. Attachment List FactBox", OnBeforeDocumentAttachmentDetailsRunModal, '', false, false)]
    local procedure FilterEDocumentAttachmentsOnBeforeDocumentAttachmentDetailsRunModal(var DocumentAttachment: Record "Document Attachment"; var DocumentAttachmentDetails: Page "Document Attachment Details")
    var
        EDocumentEntryNo: Integer;
        EDocumentEntryNoText: Text;
    begin
        DocumentAttachment.FilterGroup(4);
        EDocumentEntryNoText := DocumentAttachment.GetFilter("E-Document Entry No.");
        if EDocumentEntryNoText <> '' then begin
            Evaluate(EDocumentEntryNo, EDocumentEntryNoText);
            DocumentAttachmentDetails.FilterForEDocuments(EDocumentEntryNo);
        end;
        DocumentAttachment.FilterGroup(0);
    end;

    var
        MissingEDocumentTypeErr: Label 'E-Document type %1 is not supported for attachments', Comment = '%1 - E-Document document type';

    /// <summary>
    /// Attaches the original E-Document file to the Incoming Document of a Purchase Header.
    /// Creates an Incoming Document Attachment and links it to the Purchase Header.
    /// </summary>
    /// <param name="EDocument">The E-Document containing the file to attach</param>
    /// <param name="PurchaseHeader">The Purchase Header to attach the incoming document to</param>
    procedure AttachToIncomingDocument(EDocument: Record "E-Document"; var PurchaseHeader: Record "Purchase Header")
    var
        EDocDataStorage: Record "E-Doc. Data Storage";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        EDocumentService: Record "E-Document Service";
        ImportAttachmentIncDoc: Codeunit "Import Attachment - Inc. Doc.";
        TempBlob: Codeunit "Temp Blob";
        FileName: Text;
        EDocumentFileNameLbl: Label 'E-Document_%1.%2', Comment = '%1 = E-Document Entry No., %2 = File Format', Locked = true;
    begin
        if not (EDocument."Document Type" in [
            EDocument."Document Type"::"Purchase Invoice",
            EDocument."Document Type"::"Purchase Credit Memo",
            EDocument."Document Type"::"Purchase Order",
            EDocument."Document Type"::"Purchase Quote",
            EDocument."Document Type"::"Purchase Return Order"]) then
            exit;

        EDocumentService.Get(EDocument.Service);
        if not EDocumentService."Attach Purchase E-Document" then
            exit;
        if EDocument."Unstructured Data Entry No." = 0 then
            exit;

        if not EDocDataStorage.Get(EDocument."Unstructured Data Entry No.") then
            exit;

        TempBlob := EDocDataStorage.GetTempBlob();
        if not TempBlob.HasValue() then
            exit;

        if EDocument."File Name" <> '' then
            FileName := EDocument."File Name"
        else
            FileName := StrSubstNo(EDocumentFileNameLbl, EDocument."Entry No", EDocDataStorage."File Format");

        IncomingDocumentAttachment.SetRange("Document No.", PurchaseHeader."No.");
        IncomingDocumentAttachment.SetRange("Posting Date", PurchaseHeader."Posting Date");
        IncomingDocumentAttachment.SetContentFromBlob(TempBlob);

        if not ImportAttachmentIncDoc.ImportAttachment(IncomingDocumentAttachment, FileName, TempBlob) then
            exit;

        IncomingDocumentAttachment."Is E-Document" := true;
        IncomingDocumentAttachment.Modify(false);

        if EDocDataStorage."File Format" = EDocDataStorage."File Format"::PDF then begin
            FileName := StrSubstNo(EDocumentFileNameLbl, EDocument."Entry No", EDocDataStorage."File Format"::XML);
            ExtractXMLFromPDF(TempBlob, FileName, IncomingDocumentAttachment);
        end;

        PurchaseHeader.Validate("Incoming Document Entry No.", IncomingDocumentAttachment."Incoming Document Entry No.");
        PurchaseHeader.Modify(false);
    end;

    /// <summary>
    /// Attaches the exported E-Document XML file as an Incoming Document Attachment to the source document.
    /// Only attaches for Sales Invoice Header when the "Attach Sales E-Document" setting is enabled.
    /// </summary>
    /// <param name="EDocumentService">The E-Document Service configuration</param>
    /// <param name="EDocument">The E-Document being exported</param>
    /// <param name="SourceDocumentHeader">The source document (e.g., Sales Invoice Header)</param>
    /// <param name="TempBlob">The blob containing the exported E-Document content</param>
    internal procedure AttachIncomingDocumentOnExport(EDocumentService: Record "E-Document Service"; EDocument: Record "E-Document"; SourceDocumentHeader: RecordRef; var TempBlob: Codeunit "Temp Blob")
    var
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        ImportAttachmentIncDoc: Codeunit "Import Attachment - Inc. Doc.";
        EDocumentHelper: Codeunit "E-Document Processing";
        RecordLinkTxt: Text;
        FileNameTok: Label '%1.xml', Locked = true;
    begin
        if not (EDocument."Document Type" in [
            EDocument."Document Type"::"Sales Invoice",
            EDocument."Document Type"::"Sales Credit Memo",
            EDocument."Document Type"::"Sales Order",
            EDocument."Document Type"::"Sales Quote",
            EDocument."Document Type"::"Sales Return Order"]) then
            exit;

        if not EDocumentService."Attach Sales E-Document" then
            exit;

        RecordLinkTxt := EDocumentHelper.GetRecordLinkText(EDocument);
        IncomingDocumentAttachment.SetRange("Document No.", EDocument."Document No.");
        IncomingDocumentAttachment.SetRange("Posting Date", EDocument."Posting Date");
        IncomingDocumentAttachment.SetContentFromBlob(TempBlob);
        if not ImportAttachmentIncDoc.ImportAttachment(IncomingDocumentAttachment, StrSubstNo(FileNameTok, RecordLinkTxt), TempBlob) then
            exit;

        IncomingDocumentAttachment."Is E-Document" := true;
        IncomingDocumentAttachment.Modify(false);
    end;

}
