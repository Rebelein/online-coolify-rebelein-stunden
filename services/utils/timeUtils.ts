
/**
 * Formats a decimal duration (e.g. 8.5) to a string "HH:MM" (e.g. "08:30").
 * Handles negative numbers for differences (e.g. -0.5 -> "-00:30").
 */
export const formatDuration = (hours: number): string => {
    if (isNaN(hours)) return "00:00";

    const isNegative = hours < 0;
    const absHours = Math.abs(hours);

    // Round to nearest minute to avoid floating point issues (e.g. 0.33 hours)
    const totalMinutes = Math.round(absHours * 60);

    const h = Math.floor(totalMinutes / 60);
    const m = totalMinutes % 60;

    const formatted = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;

    return isNegative ? `-${formatted}` : formatted;
};
