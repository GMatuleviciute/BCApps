// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

enum 50001 "E-Doc. Link Action"
{
    Extensible = false;
    Access = Public;

    value(0; " ")
    {
        Caption = '';
    }
    value(1; "Linked")
    {
        Caption = 'Linked';
    }
    value(2; "Unlinked")
    {
        Caption = 'Unlinked';
    }
    value(3; "Relinked")
    {
        Caption = 'Relinked';
    }
}
