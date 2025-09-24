// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.SubscriptionBilling;

using Microsoft.Sales.Document;

/// <summary>
/// EnumExtension Sub. Billing Sales Line Type (ID 8001).
/// </summary>
enumextension 8001 "Sub. Billing Sales Line Type" extends "Sales Line Type"
{
    value(8000; "Service Object")
    {
        Caption = 'Subscription';
    }
}
