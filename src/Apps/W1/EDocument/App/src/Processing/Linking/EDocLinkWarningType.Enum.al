// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

enum 50002 "E-Doc. Link Warning Type"
{
    Extensible = true;
    Access = Public;

    value(0; "Amount Mismatch")
    {
        Caption = 'Amount Mismatch';
    }
    value(1; "VAT Mismatch")
    {
        Caption = 'VAT Amount Mismatch';
    }
    value(2; "Currency Mismatch")
    {
        Caption = 'Currency Mismatch';
    }
    value(3; "Date Mismatch")
    {
        Caption = 'Document Date Mismatch';
    }
    value(4; "Already Linked")
    {
        Caption = 'Invoice Already Linked';
    }
}
