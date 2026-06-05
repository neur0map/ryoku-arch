
function crawl(rootItem, sectionId) {
    let results = [];

    function traverse(item, currentSubSection) {
        if (!item) return;

        // Determine subsection context
        // We look for 'settingsSection' property which we will add to section containers
        let subSection = currentSubSection;
        if (item.hasOwnProperty("settingsSection")) {
            subSection = item.settingsSection;
        }

        
        let isSetting = false;
        if (item.hasOwnProperty("label") && typeof item.label === "string" && item.label.length > 0) {
            isSetting = true;
        }

        if (isSetting) {
            let label = item.label;
            
            let keywords = [];
            if (item.hasOwnProperty("keywords")) keywords.push(item.keywords);
            if (item.hasOwnProperty("description")) keywords.push(item.description);
            keywords.push(label);
            
            let icon = "";
            if (item.hasOwnProperty("icon")) icon = item.icon;

            results.push({
                label: label,
                keywords: keywords.join(" "),
                section: sectionId,
                subSection: subSection || "",
                subLabel: "",
                icon: icon,
                isIcon: true
            });
        }

        if (item.children) {
            for (let i = 0; i < item.children.length; i++) {
                traverse(item.children[i], subSection);
            }
        }
        
        if (item.contentItem) {
            traverse(item.contentItem, subSection);
        }
    }

    traverse(rootItem, "");
    return results;
}
