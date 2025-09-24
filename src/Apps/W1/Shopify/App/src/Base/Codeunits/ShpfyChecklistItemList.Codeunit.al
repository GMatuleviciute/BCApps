// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Shpfy Checklist Item List (ID 30204).
/// </summary>
codeunit 30204 "Shpfy Checklist Item List"
{
    trigger OnRun()
    begin
        Page.Run(Page::"Item List");
    end;
}