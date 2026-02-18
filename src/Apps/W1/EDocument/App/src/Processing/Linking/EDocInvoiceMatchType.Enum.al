// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

enum 50000 "E-Doc. Invoice Match Type"
{
    Extensible = false;
    Access = Public;

    value(0; " ")
    {
        Caption = '';
    }
    value(1; "Exact")
    {
        Caption = 'Exact Match';
    }
    value(2; "Strong")
    {
        Caption = 'Strong Match';
    }
    value(3; "Fallback")
    {
        Caption = 'Fallback Match';
    }
    value(4; "Manual")
    {
        Caption = 'Manual Selection';
    }
}
