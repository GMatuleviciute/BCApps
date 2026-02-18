// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.Purchases.Document;

permissionset 50030 "E-Doc. Core - Link"
{
    Assignable = true;
    Access = Public;
    Caption = 'E-Document - Link';

    IncludedPermissionSets = "E-Doc. Core - User";

    Permissions =
        tabledata "E-Document" = M,
        tabledata "E-Document Log" = IM,
        tabledata "Purchase Header" = M,
        codeunit "E-Doc. Invoice Linking" = X,
        codeunit "E-Doc. Invoice Matcher" = X,
        codeunit "E-Doc. Invoice Link Validation" = X;
}
