// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

table 50005 "E-Doc. Link Warning"
{
    Caption = 'E-Document Link Warning';
    TableType = Temporary;
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Warning Type"; Enum "E-Doc. Link Warning Type")
        {
            Caption = 'Warning Type';
        }
        field(3; "Field Name"; Text[50])
        {
            Caption = 'Field Name';
        }
        field(4; "E-Document Value"; Text[100])
        {
            Caption = 'E-Document Value';
        }
        field(5; "Purchase Invoice Value"; Text[100])
        {
            Caption = 'Purchase Invoice Value';
        }
        field(6; "Variance"; Decimal)
        {
            Caption = 'Variance';
        }
        field(7; "Severity"; Enum "E-Doc. Link Warning Severity")
        {
            Caption = 'Severity';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Severity; Severity)
        {
        }
    }
}
