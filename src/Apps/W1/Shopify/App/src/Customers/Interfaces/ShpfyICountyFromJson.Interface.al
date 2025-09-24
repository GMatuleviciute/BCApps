// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Interface Shpfy ICounty From Json.
/// </summary>
interface "Shpfy ICounty From Json"
{
    Access = Internal;

    procedure County(JAddressObject: JsonObject): Text;
}