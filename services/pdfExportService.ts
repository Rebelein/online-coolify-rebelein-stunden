import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { TimeEntry, UserSettings } from '../types';

export const generateSearchReport = (
    searchResults: TimeEntry[],
    users: UserSettings[],
    searchQuery: string
) => {
    const doc = new jsPDF();

    // Header
    doc.setFontSize(18);
    // Support utf-8 characters properly? jsPDF standard fonts might lack some special chars but basic German should work.
    doc.text(`Suchbericht: "${searchQuery}"`, 14, 20);

    doc.setFontSize(10);
    doc.text(`Erstellt am: ${new Date().toLocaleDateString('de-DE')}`, 14, 27);
    doc.text(`Gefundene Einträge: ${searchResults.length}`, 14, 32);

    // Group by User
    const grouped: Record<string, TimeEntry[]> = {};
    // Sort results by date desc first
    const sorted = [...searchResults].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    sorted.forEach(e => {
        if (!grouped[e.user_id]) grouped[e.user_id] = [];
        grouped[e.user_id].push(e);
    });

    let currentY = 45;

    // Iterate Users
    const userIds = Object.keys(grouped);

    if (userIds.length === 0) {
        doc.text("Keine Ergebnisse gefunden.", 14, currentY);
    }

    userIds.forEach((userId, index) => {
        const userEntries = grouped[userId];
        const user = users.find(u => u.user_id === userId);
        const userName = user ? user.display_name : 'Unbekannt';

        // Calculate Total Hours for this user in search
        const userTotal = userEntries.reduce((sum, e) => sum + (e.hours || 0), 0);

        // Check if we need a page break for the header
        if (currentY > 250) {
            doc.addPage();
            currentY = 20;
        }

        // User Header
        doc.setFontSize(14);
        doc.setTextColor(0, 150, 136); // Teal
        doc.text(`${userName} (${userTotal.toLocaleString('de-DE')} Std.)`, 14, currentY);
        doc.setTextColor(0, 0, 0); // Reset

        // Table Body
        const tableBody = userEntries.map(e => [
            new Date(e.date).toLocaleDateString('de-DE'),
            e.type || '',
            // Combine Client and Order Number
            e.order_number ? `${e.client_name || ''}\n#${e.order_number}` : (e.client_name || ''),
            (e.hours || 0).toLocaleString('de-DE', { minimumFractionDigits: 2 }),
            e.note || ''
        ]);

        autoTable(doc, {
            startY: currentY + 5,
            head: [['Datum', 'Typ', 'Kunde / Auftrag', 'Std', 'Notiz']],
            body: tableBody,
            theme: 'grid',
            headStyles: { fillColor: [20, 184, 166] }, // Teal-500 equivalent
            styles: { fontSize: 9, cellPadding: 2, overflow: 'linebreak' },
            columnStyles: {
                2: { cellWidth: 70 }, // Client Name wider
                4: { cellWidth: 50 }  // Note wider
            },
            margin: { left: 14, right: 14 },
            didDrawPage: (data) => {
                // Determine new Y for next loop
                // The library updates lastAutoTable.finalY automatically but we need to capture it after the table
            }
        });

        // Update Y for next section
        currentY = (doc as any).lastAutoTable.finalY + 15;
    });

    doc.save(`suchbericht_${searchQuery.replace(/[^a-z0-9]/gi, '_')}.pdf`);
};
