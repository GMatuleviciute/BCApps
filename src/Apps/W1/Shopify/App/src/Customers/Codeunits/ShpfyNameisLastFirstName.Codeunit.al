// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.Customer;

/// <summary>
/// Codeunit Shpfy Name is Last. FirstName" (ID 30122) implements Interface Shpfy ICustomer Name.
/// </summary>
codeunit 30122 "Shpfy Name is Last. FirstName" implements "Shpfy ICustomer Name"
{
    Access = Internal;

    /// <summary> 
    /// Description for GetName.
    /// </summary>
    /// <param name="FirstName">Parameter of type Text.</param>
    /// <param name="LastName">Parameter of type Text.</param>
    /// <param name="CompanyName">Parameter of type Text.</param>
    /// <returns>Return variable "Text".</returns>
    internal procedure GetName(FirstName: Text; LastName: Text; CompanyName: Text): Text
    var
        Customer: Record Customer;
        Name: Text;
        TrimmedFirstName: Text;
        TrimmedLastName: Text;
    begin
        TrimmedFirstName := FirstName.Trim();
        TrimmedLastName := LastName.Trim();
        
        // Sort the names alphabetically before concatenation
        if (TrimmedFirstName <> '') and (TrimmedLastName <> '') then begin
            if TrimmedFirstName < TrimmedLastName then
                Name := TrimmedFirstName + ' ' + TrimmedLastName
            else
                Name := TrimmedLastName + ' ' + TrimmedFirstName;
        end else if TrimmedFirstName <> '' then
            Name := TrimmedFirstName
        else
            Name := TrimmedLastName;
            
        exit(CopyStr(Name.Trim(), 1, MaxStrLen(Customer.Name)));
    end;
}