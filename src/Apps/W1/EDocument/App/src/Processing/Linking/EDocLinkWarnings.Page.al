// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

page 50021 "E-Doc. Link Warnings"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Link Warnings';
    SourceTable = "E-Doc. Link Warning";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Warnings)
            {
                ShowCaption = false;
                field(Severity; Rec.Severity)
                {
                    StyleExpr = SeverityStyleExpr;
                    ToolTip = 'Specifies the severity level of the warning: Info, Warning, or Error.';
                }
                field("Warning Type"; Rec."Warning Type")
                {
                    StyleExpr = SeverityStyleExpr;
                    ToolTip = 'Specifies the type of warning detected during link validation.';
                }
                field("Field Name"; Rec."Field Name")
                {
                    ToolTip = 'Specifies the name of the field that has a discrepancy.';
                }
                field("E-Document Value"; Rec."E-Document Value")
                {
                    ToolTip = 'Specifies the value from the e-document.';
                }
                field("Purchase Invoice Value"; Rec."Purchase Invoice Value")
                {
                    ToolTip = 'Specifies the value from the purchase invoice.';
                }
                field(Variance; Rec.Variance)
                {
                    ToolTip = 'Specifies the variance between the e-document and purchase invoice values.';
                }
            }
        }
    }

    var
        SeverityStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        UpdateStyleExpressions();
    end;

    local procedure UpdateStyleExpressions()
    begin
        // Set style based on Severity level
        case Rec.Severity of
            Rec.Severity::Info:
                SeverityStyleExpr := 'Subordinate';
            Rec.Severity::Warning:
                SeverityStyleExpr := 'Ambiguous';
            Rec.Severity::Error:
                SeverityStyleExpr := 'Unfavorable';
            else
                SeverityStyleExpr := 'Standard';
        end;
    end;

    /// <summary>
    /// Sets the warning records to display in the list.
    /// </summary>
    /// <param name="TempWarnings">The temporary warning records to display.</param>
    procedure SetWarnings(var TempWarnings: Record "E-Doc. Link Warning" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if TempWarnings.FindSet() then
            repeat
                Rec.TransferFields(TempWarnings);
                Rec.Insert();
            until TempWarnings.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Gets the count of warnings by severity level.
    /// </summary>
    /// <param name="InfoCount">Returns the count of Info level warnings.</param>
    /// <param name="WarningCount">Returns the count of Warning level warnings.</param>
    /// <param name="ErrorCount">Returns the count of Error level warnings.</param>
    procedure GetWarningCounts(var InfoCount: Integer; var WarningCount: Integer; var ErrorCount: Integer)
    var
        TempWarning: Record "E-Doc. Link Warning" temporary;
    begin
        InfoCount := 0;
        WarningCount := 0;
        ErrorCount := 0;

        TempWarning.Copy(Rec, true);
        TempWarning.Reset();

        if TempWarning.FindSet() then
            repeat
                case TempWarning.Severity of
                    TempWarning.Severity::Info:
                        InfoCount += 1;
                    TempWarning.Severity::Warning:
                        WarningCount += 1;
                    TempWarning.Severity::Error:
                        ErrorCount += 1;
                end;
            until TempWarning.Next() = 0;
    end;

    /// <summary>
    /// Checks if there are any critical (Error level) warnings.
    /// </summary>
    /// <returns>True if there are error level warnings, false otherwise.</returns>
    procedure HasCriticalWarnings(): Boolean
    var
        TempWarning: Record "E-Doc. Link Warning" temporary;
    begin
        TempWarning.Copy(Rec, true);
        TempWarning.Reset();
        TempWarning.SetRange(Severity, TempWarning.Severity::Error);
        exit(not TempWarning.IsEmpty());
    end;

    /// <summary>
    /// Checks if there are any warnings at all.
    /// </summary>
    /// <returns>True if there are any warnings, false otherwise.</returns>
    procedure HasWarnings(): Boolean
    begin
        Rec.Reset();
        exit(not Rec.IsEmpty());
    end;

    /// <summary>
    /// Gets the total count of warnings.
    /// </summary>
    /// <returns>The total number of warnings.</returns>
    procedure GetWarningCount(): Integer
    begin
        Rec.Reset();
        exit(Rec.Count());
    end;
}
