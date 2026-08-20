-- MegaMacro WoW 12.1 compatibility
-- Restores Blizzard's old BuildIconArray helper if it is no longer globally available.

if not BuildIconArray then
    function BuildIconArray(parent, baseName, template, rowSize, numRows, onButtonCreated)
        local previousButton = CreateFrame("CheckButton", baseName.."1", parent, template)
        local cornerButton = previousButton

        previousButton:SetID(1)
        previousButton:SetPoint("TOPLEFT", 26, -85)

        if onButtonCreated then
            onButtonCreated(parent, previousButton)
        end

        local numIcons = rowSize * numRows

        for i = 2, numIcons do
            local newButton = CreateFrame("CheckButton", baseName..i, parent, template)
            newButton:SetID(i)

            if i % rowSize == 1 then
                newButton:SetPoint("TOPLEFT", cornerButton, "BOTTOMLEFT", 0, -8)
                cornerButton = newButton
            else
                newButton:SetPoint("LEFT", previousButton, "RIGHT", 8, 0)
            end

            previousButton = newButton

            if onButtonCreated then
                onButtonCreated(parent, newButton)
            end
        end
    end
end