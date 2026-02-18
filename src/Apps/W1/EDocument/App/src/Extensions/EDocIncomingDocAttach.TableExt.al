// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

tableextension 6101 "E-Doc. Incoming Doc. Attach." extends "Incoming Document Attachment"
{
    fields
    {
        field(6100; "Is E-Document"; Boolean)
        {
            Caption = 'Is E-Document';
            DataClassification = SystemMetadata;
        }
    }
}