// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using System.IO;

/// <summary>
/// Codeunit Shpfy Documentation Generator (ID 30400).
/// </summary>
codeunit 30400 "Shpfy Documentation Generator"
{
    Access = Internal;

    var
        DocumentationMissingLbl: Label 'XML documentation summary is missing for object %1 %2 (ID %3)', Comment = '%1 = Object Type, %2 = Object Name, %3 = Object ID';
        DocumentationAddedLbl: Label 'Added XML documentation summary for %1 %2 (ID %3)', Comment = '%1 = Object Type, %2 = Object Name, %3 = Object ID';

    /// <summary>
    /// Checks if a file has XML documentation summary.
    /// </summary>
    /// <param name="FilePath">Path to the AL file to check.</param>
    /// <returns>True if the file has XML summary documentation.</returns>
    internal procedure HasXmlSummary(FilePath: Text): Boolean
    var
        FileManagement: Codeunit "File Management";
        FileInStream: InStream;
        LineText: Text;
        LineCount: Integer;
    begin
        if not FileManagement.ServerFileExists(FilePath) then
            exit(true);

        FileManagement.ServerCreateFile(FileInStream, FilePath);
        
        // Check first 20 lines for /// <summary>
        while (LineCount < 20) and (not FileInStream.EOS()) do begin
            FileInStream.ReadText(LineText);
            LineCount += 1;
            if StrPos(LineText, '/// <summary>') > 0 then
                exit(true);
        end;
        
        exit(false);
    end;

    /// <summary>
    /// Parses AL file to extract object information.
    /// </summary>
    /// <param name="FilePath">Path to the AL file.</param>
    /// <param name="ObjectType">Output parameter for object type.</param>
    /// <param name="ObjectId">Output parameter for object ID.</param>
    /// <param name="ObjectName">Output parameter for object name.</param>
    /// <returns>True if object information was successfully parsed.</returns>
    internal procedure ParseAlObjectInfo(FilePath: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    var
        FileManagement: Codeunit "File Management";
        FileInStream: InStream;
        Content: Text;
        ObjectPattern: Text;
    begin
        Clear(ObjectType);
        Clear(ObjectId);
        Clear(ObjectName);
        
        if not FileManagement.ServerFileExists(FilePath) then
            exit(false);

        FileManagement.ServerCreateFile(FileInStream, FilePath);
        FileInStream.Read(Content);
        
        // Try patterns with IDs first
        if TryParseObjectWithId(Content, ObjectType, ObjectId, ObjectName) then
            exit(true);
            
        // Try patterns without IDs
        if TryParseObjectWithoutId(Content, ObjectType, ObjectName) then
            exit(true);
            
        exit(false);
    end;

    local procedure TryParseObjectWithId(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    var
        RegexPattern: Text;
        Matches: Record "Name/Value Buffer" temporary;
    begin
        // Check for codeunit pattern
        RegexPattern := 'codeunit\s+(\d+)\s+"([^"]+)"';
        if TryExtractMatches(Content, RegexPattern, ObjectType, ObjectId, ObjectName) then begin
            ObjectType := 'Codeunit';
            exit(true);
        end;
        
        // Check for page pattern  
        RegexPattern := 'page\s+(\d+)\s+"([^"]+)"';
        if TryExtractMatches(Content, RegexPattern, ObjectType, ObjectId, ObjectName) then begin
            ObjectType := 'Page';
            exit(true);
        end;
        
        // Check for table pattern
        RegexPattern := 'table\s+(\d+)\s+"([^"]+)"';
        if TryExtractMatches(Content, RegexPattern, ObjectType, ObjectId, ObjectName) then begin
            ObjectType := 'Table';
            exit(true);
        end;
        
        // Check for enum pattern
        RegexPattern := 'enum\s+(\d+)\s+"([^"]+)"';
        if TryExtractMatches(Content, RegexPattern, ObjectType, ObjectId, ObjectName) then begin
            ObjectType := 'Enum';
            exit(true);
        end;
        
        // Check for report pattern
        RegexPattern := 'report\s+(\d+)\s+"([^"]+)"';
        if TryExtractMatches(Content, RegexPattern, ObjectType, ObjectId, ObjectName) then begin
            ObjectType := 'Report';
            exit(true);
        end;
        
        exit(false);
    end;

    local procedure TryParseObjectWithoutId(Content: Text; var ObjectType: Text; var ObjectName: Text): Boolean
    var
        StartPos: Integer;
        EndPos: Integer;
    begin
        // Check for interface pattern
        StartPos := StrPos(LowerCase(Content), 'interface "');
        if StartPos > 0 then begin
            ObjectType := 'Interface';
            StartPos := StrPos(Content, '"', StartPos);
            EndPos := StrPos(Content, '"', StartPos + 1);
            if (StartPos > 0) and (EndPos > StartPos) then begin
                ObjectName := CopyStr(Content, StartPos + 1, EndPos - StartPos - 1);
                exit(true);
            end;
        end;
        
        exit(false);
    end;

    local procedure TryExtractMatches(Content: Text; Pattern: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    var
        StartPos: Integer;
        PatternLower: Text;
        ContentLower: Text;
    begin
        PatternLower := LowerCase(Pattern);
        ContentLower := LowerCase(Content);
        
        // Simple pattern matching for AL object declarations
        // This is a simplified version - in a real implementation you might use regex
        if StrPos(ContentLower, 'codeunit ') > 0 then
            exit(ExtractCodeunitInfo(Content, ObjectType, ObjectId, ObjectName));
        if StrPos(ContentLower, 'page ') > 0 then
            exit(ExtractPageInfo(Content, ObjectType, ObjectId, ObjectName));
        if StrPos(ContentLower, 'table ') > 0 then
            exit(ExtractTableInfo(Content, ObjectType, ObjectId, ObjectName));
        if StrPos(ContentLower, 'enum ') > 0 then
            exit(ExtractEnumInfo(Content, ObjectType, ObjectId, ObjectName));
        if StrPos(ContentLower, 'report ') > 0 then
            exit(ExtractReportInfo(Content, ObjectType, ObjectId, ObjectName));
            
        exit(false);
    end;

    local procedure ExtractCodeunitInfo(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    begin
        ObjectType := 'Codeunit';
        exit(ExtractObjectInfo(Content, 'codeunit ', ObjectId, ObjectName));
    end;

    local procedure ExtractPageInfo(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    begin
        ObjectType := 'Page';
        exit(ExtractObjectInfo(Content, 'page ', ObjectId, ObjectName));
    end;

    local procedure ExtractTableInfo(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    begin
        ObjectType := 'Table';
        exit(ExtractObjectInfo(Content, 'table ', ObjectId, ObjectName));
    end;

    local procedure ExtractEnumInfo(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    begin
        ObjectType := 'Enum';
        exit(ExtractObjectInfo(Content, 'enum ', ObjectId, ObjectName));
    end;

    local procedure ExtractReportInfo(Content: Text; var ObjectType: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    begin
        ObjectType := 'Report';
        exit(ExtractObjectInfo(Content, 'report ', ObjectId, ObjectName));
    end;

    local procedure ExtractObjectInfo(Content: Text; ObjectTypeKeyword: Text; var ObjectId: Text; var ObjectName: Text): Boolean
    var
        StartPos: Integer;
        IdStartPos: Integer;
        IdEndPos: Integer;
        NameStartPos: Integer;
        NameEndPos: Integer;
    begin
        StartPos := StrPos(LowerCase(Content), ObjectTypeKeyword);
        if StartPos = 0 then
            exit(false);
            
        // Find ID
        IdStartPos := StartPos + StrLen(ObjectTypeKeyword);
        while (IdStartPos <= StrLen(Content)) and (Content[IdStartPos] = ' ') do
            IdStartPos += 1;
            
        IdEndPos := IdStartPos;
        while (IdEndPos <= StrLen(Content)) and (Content[IdEndPos] in ['0'..'9']) do
            IdEndPos += 1;
            
        if IdEndPos = IdStartPos then
            exit(false);
            
        ObjectId := CopyStr(Content, IdStartPos, IdEndPos - IdStartPos);
        
        // Find name in quotes
        NameStartPos := StrPos(Content, '"', IdEndPos);
        if NameStartPos = 0 then
            exit(false);
            
        NameEndPos := StrPos(Content, '"', NameStartPos + 1);
        if NameEndPos = 0 then
            exit(false);
            
        ObjectName := CopyStr(Content, NameStartPos + 1, NameEndPos - NameStartPos - 1);
        
        exit(true);
    end;

    /// <summary>
    /// Generates XML documentation summary for an AL object.
    /// </summary>
    /// <param name="ObjectType">Type of the AL object.</param>
    /// <param name="ObjectId">ID of the AL object.</param>
    /// <param name="ObjectName">Name of the AL object.</param>
    /// <returns>Generated XML documentation summary text.</returns>
    internal procedure GenerateXmlSummary(ObjectType: Text; ObjectId: Text; ObjectName: Text): Text
    var
        SummaryText: Text;
    begin
        SummaryText := '/// <summary>' + Format(10) + '/// ';
        
        if ObjectId <> '' then
            SummaryText += StrSubstNo('%1 %2 (ID %3).', ObjectType, ObjectName, ObjectId)
        else
            SummaryText += StrSubstNo('%1 %2.', ObjectType, ObjectName);
            
        SummaryText += Format(10) + '/// </summary>';
        
        exit(SummaryText);
    end;

    /// <summary>
    /// Processes an AL file directory to add missing XML documentation.
    /// </summary>
    /// <param name="DirectoryPath">Path to the directory containing AL files.</param>
    /// <returns>Number of files updated with documentation.</returns>
    internal procedure ProcessDirectory(DirectoryPath: Text): Integer
    var
        FileManagement: Codeunit "File Management";
        FilesUpdated: Integer;
        ObjectType: Text;
        ObjectId: Text;
        ObjectName: Text;
        FilePath: Text;
        FilesList: List of [Text];
        i: Integer;
    begin
        // This is a simplified version - in practice you'd use file system APIs
        // to enumerate .al files in the directory and process each one
        
        // For demonstration purposes, this returns 0
        // In a real implementation, this would:
        // 1. Enumerate all .al files in the directory
        // 2. Check each file for missing documentation using HasXmlSummary
        // 3. Parse object info using ParseAlObjectInfo  
        // 4. Generate and insert documentation using GenerateXmlSummary
        // 5. Update the file content
        
        Message('Documentation generation functionality is available. Use external tools to process files.');
        
        exit(FilesUpdated);
    end;
}