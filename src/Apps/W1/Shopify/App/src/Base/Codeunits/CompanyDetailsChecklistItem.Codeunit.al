// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Utilities;

/// <summary>
/// Codeunit Company Details Checklist Item (ID 30203).
/// </summary>
codeunit 30203 "Company Details Checklist Item"
{
    Access = Internal;

    trigger OnRun()
    begin
        Page.Run(Page::"Assisted Company Setup Wizard");
    end;
}