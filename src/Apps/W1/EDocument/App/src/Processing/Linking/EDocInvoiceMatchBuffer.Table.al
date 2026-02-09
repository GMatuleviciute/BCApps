// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

table 50004 "E-Doc. Invoice Match Buffer"
{
    Caption = 'E-Document Invoice Match Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Purchase Header SystemId"; Guid)
        {
            Caption = 'Purchase Header System ID';
        }
        field(3; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(4; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
        }
        field(5; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
        }
        field(6; "Vendor Invoice No."; Code[35])
        {
            Caption = 'Vendor Invoice No.';
        }
        field(7; "Amount Including VAT"; Decimal)
        {
            Caption = 'Amount Including VAT';
        }
        field(8; "Document Date"; Date)
        {
            Caption = 'Document Date';
        }
        field(9; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
        }
        field(10; "Match Score"; Integer)
        {
            Caption = 'Match Score';
        }
        field(11; "Match Type"; Enum "E-Doc. Invoice Match Type")
        {
            Caption = 'Match Type';
        }
        field(12; "Already Linked"; Boolean)
        {
            Caption = 'Already Linked';
        }
        field(13; "Linked E-Document Entry No"; Integer)
        {
            Caption = 'Linked E-Document Entry No';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Score; "Match Score")
        {
        }
    }
}
