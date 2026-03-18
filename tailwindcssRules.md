╔══════════════════════════════════════════════════════════════╗
║           STYLING RULES — TARMEEZ PLATFORM                  ║
║           Tailwind CSS v4 + shadcn/ui + RTL                 ║
╚══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Framework:  Next.js 16+ | React 19+
CSS:        Tailwind CSS v4 (@import "tailwindcss")
Components: shadcn/ui
Theme:      next-themes (dark/light toggle)
Direction:  RTL Arabic (dir="rtl" on <html>)

The single source of truth for ALL colors is:
app/globals.css → CSS variables → @theme inline

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 1] SEMANTIC TOKENS ONLY — NO RAW COLORS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NEVER use raw Tailwind color classes for backgrounds,
text, or borders. ALWAYS use semantic token classes.

These automatically adapt to dark/light mode:

BACKGROUNDS:
❌ bg-white, bg-gray-50, bg-gray-100, bg-slate-50
❌ bg-gray-900, bg-slate-800, bg-slate-900
✅ bg-background      ← page background
✅ bg-card            ← card/panel background
✅ bg-muted           ← subtle background
✅ bg-popover         ← dropdown/popover background
✅ bg-sidebar         ← sidebar background

TEXT:
❌ text-black, text-white
❌ text-gray-900, text-gray-700, text-gray-600
❌ text-gray-500, text-gray-400, text-gray-300
❌ text-slate-900, text-slate-700, text-slate-600
✅ text-foreground          ← primary text
✅ text-muted-foreground    ← secondary/subtle text
✅ text-card-foreground     ← text on cards
✅ text-popover-foreground  ← text in dropdowns

BORDERS:
❌ border-gray-200, border-gray-300
❌ border-slate-200, border-slate-100
✅ border-border       ← default border
✅ divide-border       ← for divide-y/x

INTERACTIVE:
❌ hover:bg-gray-100, hover:bg-gray-50
❌ hover:bg-slate-100, hover:bg-slate-50
✅ hover:bg-muted      ← hover on interactive items
✅ hover:bg-accent     ← hover with accent

SEMANTIC COLORS (for status):
✅ bg-primary text-primary-foreground
✅ bg-secondary text-secondary-foreground
✅ bg-destructive text-destructive-foreground
✅ bg-accent text-accent-foreground

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 2] USE SHADCN COMPONENTS — NEVER RAW HTML
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
shadcn components already use semantic tokens internally.
Using them guarantees dark/light mode works automatically.

ALWAYS use:
✅ <Card> <CardHeader> <CardContent> <CardTitle>
   → never: <div className="bg-white rounded-lg shadow">

✅ <Table> <TableHeader> <TableRow> <TableHead> <TableCell>
   → never: <table className="bg-white">

✅ <Badge variant="...">
   → never: <span className="bg-blue-100 text-blue-800">

✅ <Button variant="...">
   → never: <button className="bg-blue-600 text-white">

✅ <Input> <Textarea> <Select>
   → never: <input className="bg-white border-gray-300">

✅ <Separator>
   → never: <hr className="border-gray-200">

✅ <Dialog> <DialogContent> <DialogHeader>
   → never: custom modal divs with bg-white

✅ <Tabs> <TabsList> <TabsTrigger> <TabsContent>
   → never: custom tab implementations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 3] RTL — LOGICAL PROPERTIES ONLY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Use CSS logical properties — they adapt to RTL/LTR:

PADDING:
❌ pl-4, pr-4  → ✅ ps-4 (start), pe-4 (end)
❌ pl-2, pr-2  → ✅ ps-2, pe-2

MARGIN:
❌ ml-4, mr-4  → ✅ ms-4 (start), me-4 (end)
❌ ml-auto     → ✅ ms-auto
❌ mr-auto     → ✅ me-auto

BORDER:
❌ border-l, border-r  → ✅ border-s (start), border-e (end)
❌ rounded-l, rounded-r → ✅ rounded-s, rounded-e

TEXT ALIGNMENT:
❌ text-left, text-right  → ✅ text-start, text-end
   EXCEPTION: numerical values explicitly need text-start

POSITION (for absolutely positioned elements):
❌ left-0, right-0  → ✅ start-0, end-0

EXCEPTION — when physical direction is explicitly intended:
   e.g. icon rotation, decorative elements → use physical

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 4] STATUS COLORS — USE SEMANTIC VARIANTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
For status badges and alerts, use shadcn Badge variants
OR Tailwind semantic status classes:

✅ SUCCESS:
   <Badge className="bg-green-100 text-green-800
     dark:bg-green-900 dark:text-green-200">
   Note: green has no semantic token — must include
   dark: variant explicitly.

✅ WARNING:
   <Badge className="bg-yellow-100 text-yellow-800
     dark:bg-yellow-900 dark:text-yellow-200">

✅ ERROR/DANGER:
   <Badge variant="destructive">
   OR: className="bg-destructive text-destructive-foreground"

✅ INFO:
   <Badge className="bg-blue-100 text-blue-800
     dark:bg-blue-900 dark:text-blue-200">

✅ NEUTRAL:
   <Badge variant="secondary">
   OR: className="bg-muted text-muted-foreground"

RULE: If using a color that has no semantic token (green,
yellow, blue for status), ALWAYS include the dark: variant.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 5] CHARTS AND DATA VISUALIZATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
For charts use the CSS chart variables from globals.css:
  --chart-1 through --chart-5
  → Already defined for both light and dark mode.

In recharts or any chart library:
  stroke="var(--color-chart-1)"
  fill="var(--color-chart-2)"

Never hardcode chart colors:
❌ stroke="#3b82f6"
✅ stroke="var(--color-chart-1)"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 6] INLINE STYLES — ONLY FOR DYNAMIC VALUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Inline styles are ONLY allowed for:
- Dynamic values from props/state
- CSS variables from store theme (--p-color etc.)
- Values not expressible as Tailwind classes

❌ style={{ backgroundColor: 'white' }}
❌ style={{ color: '#374151' }}
✅ style={{ backgroundColor: 'var(--p-color)' }}
✅ style={{ width: `${dynamicWidth}px` }}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 7] TYPOGRAPHY SCALE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Use consistent typography across all dashboard pages:

Page title:      text-2xl font-bold text-foreground
Section title:   text-lg font-semibold text-foreground
Card title:      text-base font-semibold text-foreground
Body text:       text-sm text-foreground
Subtle/label:    text-sm text-muted-foreground
Caption/hint:    text-xs text-muted-foreground

Numbers/stats:   text-3xl font-bold text-foreground
                 (or text-primary for highlighted metrics)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 8] SPACING AND LAYOUT CONSISTENCY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dashboard pages use consistent spacing:

Page wrapper:    p-6 space-y-6
Stats row:       grid grid-cols-2 md:grid-cols-4 gap-4
Card padding:    p-6 (from shadcn Card default)
Section gap:     space-y-4
Table wrapper:   rounded-lg border border-border overflow-hidden

Header pattern:
  <div className="flex items-center justify-between">
    <div>
      <h1 className="text-2xl font-bold text-foreground">
      <p className="text-sm text-muted-foreground">
    </div>
    <div className="flex items-center gap-2">
      {/* actions */}
    </div>
  </div>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 9] DARK MODE — HOW IT WORKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dark mode applies via .dark class on <html>
managed by next-themes.

globals.css defines:
  :root { /* light values */ }
  .dark { /* dark values */ }

When dark class is present, all CSS variables
automatically switch to dark values.

Semantic Tailwind classes (bg-background, etc.)
read from CSS variables → dark mode is automatic.

You NEVER need to write dark: prefix for:
  bg-background, bg-card, bg-muted, bg-sidebar
  text-foreground, text-muted-foreground
  border-border

You ONLY need dark: prefix for:
  Status colors (green, yellow, blue — STYLE-RULE 4)
  Custom one-off colors with no semantic token

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STYLE-RULE 10] CHECKLIST BEFORE EVERY COMPONENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Before marking any dashboard component done:

□ Zero bg-white, bg-gray-*, bg-slate-* classes
□ Zero text-black, text-white (unless on explicit bg)
□ Zero text-gray-*, text-slate-* classes
□ Zero border-gray-*, border-slate-* classes
□ All cards use shadcn <Card> component
□ All tables use shadcn <Table> component
□ All buttons use shadcn <Button> with variant
□ All inputs use shadcn <Input>
□ Padding/margin use logical properties (ps/pe/ms/me)
□ Text alignment uses text-start/text-end
□ Status badges include dark: variant if needed
□ Chart colors use var(--color-chart-*)
□ No inline style with hardcoded color hex
□ Looks correct in BOTH light AND dark mode

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STRICT WARNINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✗ Never write bg-white or bg-gray-* anywhere
✗ Never write text-black or text-gray-* anywhere
✗ Never write border-gray-* anywhere
✗ Never use raw <div> as a card — use <Card>
✗ Never use raw <table> — use shadcn <Table>
✗ Never use physical padding/margin (pl/pr/ml/mr)
  unless physical direction is explicitly required
✗ Never hardcode chart colors as hex values
✗ Never write dark: prefix for semantic token classes
  (they handle dark mode automatically)