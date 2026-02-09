// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

enum 50003 "E-Doc. Link Warning Severity"
{
    Extensible = false;
    Access = Public;

    value(0; "Info")
    {
        Caption = 'Info';
    }
    value(1; "Warning")
    {
        Caption = 'Warning';
    }
    value(2; "Error")
    {
        Caption = 'Error';
    }
}
