// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

/// <summary>
/// Dialog page for entering an override reason when relinking an E-Document to a different Purchase Invoice.
/// </summary>
page 50022 "E-Doc. Link Override"
{
    Caption = 'Override Existing Link';
    PageType = StandardDialog;
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(InfoGroup)
            {
                Caption = 'Information';
                InstructionalText = 'The selected Purchase Invoice is already linked to another E-Document. Please provide a reason for overriding the existing link.';
            }
            group(ReasonGroup)
            {
                ShowCaption = false;

                field(OverrideReasonField; OverrideReason)
                {
                    ApplicationArea = All;
                    Caption = 'Override Reason';
                    ToolTip = 'Specifies the reason for overriding the existing link. This field is mandatory.';
                    MultiLine = true;
                    ShowMandatory = true;
                    NotBlank = true;

                    trigger OnValidate()
                    begin
                        ValidateReason();
                    end;
                }
            }
        }
    }

    var
        OverrideReason: Text[250];
        ReasonRequiredErr: Label 'You must provide a reason for overriding the existing link.';

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then
            exit(IsReasonValid());
        exit(true);
    end;

    local procedure ValidateReason()
    begin
        if OverrideReason = '' then
            Error(ReasonRequiredErr);
    end;

    local procedure IsReasonValid(): Boolean
    begin
        if OverrideReason = '' then begin
            Error(ReasonRequiredErr);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Gets the override reason entered by the user.
    /// </summary>
    /// <returns>The override reason text.</returns>
    procedure GetOverrideReason(): Text[250]
    begin
        exit(OverrideReason);
    end;

    /// <summary>
    /// Sets the initial override reason value.
    /// </summary>
    /// <param name="InitialReason">The initial reason text to display.</param>
    procedure SetOverrideReason(InitialReason: Text[250])
    begin
        OverrideReason := InitialReason;
    end;
}
