// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.SubscriptionBilling;

using Microsoft.Sales.Document;

/// <summary>
/// ReportExtension Contract Blanket Sales Order (ID 8009).
/// </summary>
reportextension 8009 "Contract Blanket Sales Order" extends "Blanket Sales Order"
{
    dataset
    {
        modify(RoundLoop)
        {
            trigger OnAfterAfterGetRecord()
            begin
                SalesReportPrintoutMgmt.ExcludeItemFromTotals("Sales Line", TotalSalesLineAmount, TotalSalesInvDiscAmount, VATBaseAmount, VATAmount, TotalAmountInclVAT);
            end;
        }
    }
    var
        SalesReportPrintoutMgmt: Codeunit "Sales Report Printout Mgmt.";
}
