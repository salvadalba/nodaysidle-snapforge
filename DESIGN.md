# SnapForge — AI-Powered Screen Capture Studio for macOS
**Type:** brand identity

## Brand Context
**Industry:** Developer Tools / Productivity Software / macOS Utilities
**Market:** Global with US-centric Apple developer ecosystem — San Francisco tech corridor aesthetic with Cupertino hardware-software integration sensibility
**Audience:** Professional macOS power users aged 25-45 — software engineers, product designers, technical writers, and content creators who treat their tools as craft instruments and will pay $29-49 for software that respects their workflow, privacy, and taste
**Personality:** Precision-crafted,Quietly intelligent,Privacy-confident,Workflow-native,Optically warm

### Cultural Notes
Apple ecosystem design language demands precision, restraint, and spatial hierarchy. The target market expects SF Pro-adjacent typography, vitreous material layers, and the kind of considered negative space that signals 'this app belongs on your Mac.' US developer-tool branding currently splits between two poles: warm-craft (Linear, Raycast) and cold-precision (Xcode, Instruments). SnapForge must occupy the warm-precision middle — technically credible yet approachable. Privacy-first messaging resonates strongly in post-GDPR, post-ATT developer culture where 'on-device' is a trust signal, not a limitation. The radial command palette and HUD overlays demand a design system that reads clearly at 12px on a 5K Retina display and at 200px on a marketing hero.

## Design Direction
**Style:** Apple Human Interface-adjacent with warm-precision character — vitreous material layers, spatial depth through shadow and blur, geometric iconography with 2px rounded stroke consistency, light mode primary with full dark mode parity
**Mood:** Quietly powerful — the calm confidence of a precision instrument that doesn't need to shout. Think: the moment you pick up a well-balanced tool and it just fits. Warm enough to feel personal, sharp enough to feel professional. Intelligence is ambient, not performative.
**Composition:** Spatial depth composition with three material planes: background linen → frosted glass panels (.ultraThinMaterial) → floating HUD elements (.regularMaterial with shadow). Asymmetric grid with 60/40 split for library browser, centered radial layout for command palette, fixed horizontal strip for action bar. Marketing layouts use Apple-style centered hero with generous vertical rhythm (80px+ section spacing). App icon uses a rounded-rect forge anvil with orange-to-gold gradient and subtle depth shadow.
**Typography:** SF Pro Display (marketing/headlines) at semibold 600 with -0.02em tracking for tightness; SF Pro Text (UI/body) at regular 400 with default tracking; SF Mono (code contexts, OCR results, API documentation) at medium 500. Fallback system: -apple-system for web. Size scale follows Apple's type ramp: 34/28/22/17/15/13/11. All type set with optical sizing enabled for Retina clarity.

### Color Palette
- **Primary:** #E8620A - Forge Orange — a deep, warm amber-orange inspired by molten metal and the creative act of forging; distinguishes from CleanShot's cool blue
- **Secondary:** #1C1C1E - System Black — Apple's semantic dark surface color for text, toolbars, and high-contrast UI chrome
- **Accent:** #FF9F0A - Spark Gold — Apple's system orange-gold, used for active states, AI indicators, and streaming token highlights
- **Background:** #F5F5F7 - Apple Linen — the warm near-white Apple uses for marketing surfaces; avoids clinical sterility while maintaining clarity

> Orange-amber positions SnapForge as the warm counterpoint to CleanShot X's cool blue (#2196F3) and screenshot.app's neutral gray. Forge Orange connotes creation, heat, and transformation — the act of forging raw captures into knowledge. The palette deliberately avoids blue (oversaturated in dev tools), purple (too playful for a precision tool), and green (health/finance associations). Gold accent doubles as the AI activity indicator, creating a semantic link between 'intelligence' and 'warmth.' The near-white background reads as premium on Apple marketing pages while the system black provides WCAG AAA contrast at all text sizes.

## Reference Image Analysis
No reference image provided. Design direction is derived from competitive analysis of CleanShot X (cool blue, utilitarian), Raycast (warm neutral, craft), Linear (purple-warm, editorial), and Apple's own Screenshot.app (minimal, system-native). SnapForge's visual identity must feel like it ships with macOS but has more personality than a system utility — the sweet spot occupied by apps like Things 3 and Fantastical.

---

## Design Prompt (Universal)
```
Design a comprehensive brand identity for SnapForge, a premium macOS screen capture studio with on-device AI. The visual system centers on Forge Orange (#E8620A) as the primary brand color — a deep warm amber-orange evoking molten metal and the creative act of forging captures into knowledge. Secondary palette: System Black (#1C1C1E) for text and chrome, Spark Gold (#FF9F0A) for AI activity states and interactive highlights, Apple Linen (#F5F5F7) for backgrounds. Typography uses SF Pro Display semibold for headlines with tight -0.02em tracking, SF Pro Text regular for body, SF Mono medium for code/OCR contexts. The app icon is a rounded-rectangle macOS icon featuring a stylized anvil or forge spark symbol with an orange-to-gold diagonal gradient, subtle inner shadow for depth, and a thin 0.5px highlight rim — it must read clearly at 16px menu bar size and 512px App Store size. The design system includes: (1) a floating radial command palette with six circular capture-type buttons on a frosted glass (.ultraThinMaterial) disk, (2) a horizontal HUD action bar with seven fixed-order buttons using 2px-stroke SF Symbol icons on a dark translucent panel, (3) a library browser with sidebar navigation, thumbnail grid with orange selection rings, and a search bar with FTS5-powered instant results, (4) an AI streaming panel showing token-by-token text appearance with a pulsing gold dot indicator, provider badge, and elapsed time. All UI elements use macOS vitreous material layers with spatial depth through layered shadows (0/2/8px at 0.12 opacity). The overall aesthetic is Apple Human Interface-adjacent with warm-precision character — technically credible yet approachable, sitting between Linear's craft warmth and Xcode's cold precision. Privacy is communicated through a shield icon motif and explicit local/cloud toggle UI, not through fortress metaphors. Dark mode inverts to #000000 true black backgrounds with orange accents maintaining identical vibrancy. Marketing collateral uses centered layouts with 80px+ vertical rhythm, a single hero screenshot floating on the linen background with a subtle drop shadow, and the tagline 'Forge Every Capture Into Knowledge' in SF Pro Display 34pt semibold.
```

## Negative Prompt
```
Avoid blue color schemes (CleanShot territory), neon/cyberpunk aesthetics, flat illustration style characters, playful rounded bubble UI, skeuomorphic textures (leather, wood, felt), aggressive gradients, dark-only designs without light mode, cluttered information density, Windows/Material Design language, generic stock photography, abstract blob shapes, corporate stiffness, startup-culture playfulness, any suggestion of cloud dependency or surveillance, cheap glossy reflections, beveled edges, drop shadows heavier than 0.15 opacity, any typeface other than SF Pro family in UI contexts
```

---

## Google Imagen 3
```
A premium macOS application brand identity for SnapForge, a screen capture tool. Show a beautifully crafted macOS app icon: a rounded rectangle with a stylized forge anvil and spark symbol in warm orange (#E8620A) to gold (#FF9F0A) gradient, subtle inner shadow for depth, on a clean white background. Next to the icon, display the app name 'SnapForge' in a clean sans-serif font (semibold weight, tight letter-spacing). Below, show a frosted glass floating panel with six circular buttons arranged in a radial pattern — each button contains a minimal line icon representing different capture types (camera, scroll, video, scissors, text scan, pin). The overall aesthetic is Apple-native, warm yet precise, with the confidence of a professional macOS utility. Soft directional lighting from top-left, subtle ambient occlusion shadows. Ultra high quality, 4K resolution, photorealistic materials with frosted glass translucency.
```

## Minimax
```
macOS app brand identity: SnapForge screen capture tool. Rounded-rect app icon with orange-to-gold gradient forge spark symbol, frosted glass command palette with radial button layout, clean SF Pro typography, warm precision aesthetic, Apple HIG-compliant design, #E8620A primary orange, #FF9F0A gold accent, #F5F5F7 linen background, professional developer tool branding, 4K quality
```

## Midjourney v6
```
Premium macOS application brand identity for 'SnapForge' -- a screen capture studio with on-device AI. Centered app icon: rounded rectangle, stylized forge anvil with spark, warm orange #E8620A to gold #FF9F0A diagonal gradient, subtle depth shadow. Floating frosted glass command palette panel with six radial capture-type buttons, SF Symbol-style line icons. Clean typography 'SnapForge' in tight semibold sans-serif. Apple Human Interface aesthetic, vitreous material layers, spatial depth, warm linen #F5F5F7 background. Professional, quietly intelligent, precision-crafted. Studio lighting, 4K detail --ar 16:9 --style raw --v 6 --s 200 --no blue, neon, playful, cartoon, glossy
```

## DALL-E 3
```
Create a detailed brand identity presentation for SnapForge, a premium macOS screen capture application. The composition shows: TOP — a polished macOS app icon (rounded rectangle with smooth corners) featuring a stylized forge anvil with a single spark, rendered in a warm orange (#E8620A) to gold (#FF9F0A) gradient with a subtle inner highlight and soft drop shadow, floating above a light warm-gray (#F5F5F7) background. MIDDLE — the word 'SnapForge' typeset in a clean, tight, semibold sans-serif font in near-black (#1C1C1E). BOTTOM — a frosted glass panel (translucent, blurred background showing through) containing six circular buttons arranged in a radial pattern, each with a thin 2px stroke icon representing a capture type (camera, scroll arrow, video camera, scissors, text lines, pin). The overall design language is Apple-native — precise, warm, spatially layered with material depth. The mood is quietly confident and professional, like a premium developer tool. No blue colors, no playful elements, no cartoon style. Photorealistic material rendering, 4K resolution.
```

## Stable Diffusion XL
```
(masterpiece, best quality, ultra-detailed:1.4), macOS application brand identity design, app icon rounded rectangle with forge anvil spark symbol, (warm orange gradient:1.3) #E8620A to #FF9F0A, subtle inner shadow depth, frosted glass translucent panel, (radial button layout:1.2), six circular capture type icons, thin 2px stroke line icons, clean sans-serif typography 'SnapForge' semibold tight tracking, (Apple HIG design language:1.3), vitreous material layers, spatial depth shadows, warm linen background #F5F5F7, near-black text #1C1C1E, professional developer tool aesthetic, (precision crafted:1.2), studio lighting, 4K resolution, photorealistic materials BREAK (negative:1.4) blue color scheme, neon glow, cyberpunk, cartoon, illustration style, playful rounded bubble UI, skeuomorphic texture, aggressive gradient, dark only, cluttered, Windows UI, stock photo, abstract blob, glossy reflection, bevel
```

---

## Layout Mockup Prompt
```
A landscape 16:9 brand presentation board on a warm linen (#F5F5F7) background with soft ambient shadow around the edges. TOP-LEFT: the SnapForge app icon at 256px — a rounded macOS rectangle with a stylized anvil-and-spark mark in an orange-to-gold diagonal gradient, floating with a 16px soft shadow beneath it. TOP-RIGHT: 'SnapForge' logotype in SF Pro Display semibold 48pt near-black (#1C1C1E) with the tagline 'Forge Every Capture Into Knowledge' below in SF Pro Text regular 18pt warm gray (#86868B), left-aligned. CENTER: a large MacBook Pro screen mockup (slightly rotated 2° for depth) displaying the SnapForge library browser — a sidebar on the left with capture type filters and tag cloud, a thumbnail grid on the right with one item selected (orange ring highlight #E8620A), and a search bar at the top with the placeholder 'Search captures...' in light gray. Floating ABOVE the MacBook screen at top-right: the frosted glass command palette — a circular disk with six radial buttons (Screenshot, Region, Scrolling, Video, GIF, OCR) using thin white SF Symbol icons on slightly darker frosted circles, the whole panel having a .ultraThinMaterial blur effect with a 1px white border at 0.2 opacity. BELOW the MacBook at bottom-center: the HUD action bar — a dark translucent horizontal strip with seven evenly-spaced buttons (Annotate pencil, Copy clipboard, Save folder, Cloud upload, Background rectangle, Pin pushpin, Delete trash) as 2px-stroke white icons, the 'Copy' button highlighted in Spark Gold (#FF9F0A) indicating last-used action. BOTTOM-RIGHT corner: a small AI streaming panel mockup — a frosted card showing three lines of text appearing token-by-token with a pulsing gold dot at the insertion point, a 'CoreML' provider badge in a rounded gray pill, and '1.2s · 47 tokens' in caption text below. The entire composition uses three distinct depth layers: linen background → MacBook mockup → floating glass panels, creating a spatial hierarchy that demonstrates the app's material design language. Color swatches for #E8620A, #FF9F0A, #1C1C1E, and #F5F5F7 run as small circles along the very bottom edge.
```
*Copy this into any AI image tool to generate a sketch showing logo placement, brand positioning, and visual hierarchy.*

## Variations
### 1. Variation 1 — Forge Heritage: Emphasize the craftsmanship metaphor with deeper, richer tones. Primary shifts to #C4520A (burnt sienna forge), backgrounds warm to #FAF8F5 (parchment linen). Typography adds subtle letter-spacing to headlines for an engraved quality. App icon features a detailed anvil with hammer-strike spark particles in gold. UI panels use slightly thicker borders (1px vs 0.5px) and warmer shadow tints (#E8620A at 0.06 opacity). Command palette buttons have a hammered-metal micro-texture on hover. Marketing uses a single centered forge anvil illustration with radiating spark lines. Tagline set in SF Pro Display with increased tracking (+0.04em) for a chiseled, authoritative feel. This variation leans toward the premium utility aesthetic of Things 3 — understated, tactile, lasting.

### 2. Variation 2 — Spark Intelligence: Lead with the AI-forward identity. Primary shifts to #FF9F0A (Spark Gold promoted to primary), with #E8620A demoted to secondary warmth anchor. Backgrounds use a subtle warm-to-cool gradient (#F5F5F7 → #F0F2F5) suggesting computational depth. App icon features an abstract neural-spark symbol — intersecting arcs forming a stylized eye/lens with a gold core pulse. AI streaming UI gets a dedicated glow effect (gold outer shadow, 12px blur). Command palette icons have a micro-animation dot grid background suggesting active intelligence. Typography remains SF Pro but headlines use light 300 weight for a more ethereal, forward-looking feel. Marketing hero shows a screenshot being analyzed with gold overlay lines tracing detected UI regions. This variation positions SnapForge as an AI-native tool that happens to capture screens, appealing to early-adopter developers excited by on-device ML.

### 3. Variation 3 — Minimal System: Strip to essentials — position SnapForge as the screenshot tool Apple should have built. Primary reduces to a single accent: #E8620A used only for selection states and the menu bar icon. All other UI is monochromatic: #1C1C1E text, #F5F5F7 backgrounds, #E5E5EA borders (Apple's system gray 5). App icon is a minimal rounded-rect with a single diagonal forge-spark stroke in orange on white — reads as a system utility icon. Typography uses SF Pro at default weights with no tracking adjustments. UI panels use system-standard .ultraThinMaterial without custom shadows. Command palette is a standard NSPanel text field with type-ahead (Spotlight-style) rather than radial layout. Marketing is stark: white background, floating MacBook screenshot, small centered logo, no tagline — just 'SnapForge' in SF Pro Display medium. This variation sacrifices personality for ultimate system integration, appealing to minimalists who want their tools invisible.

## Suggested Mockups
- macOS menu bar icon — 22x22pt forge spark symbol in template rendering mode (monochrome adapting to light/dark system appearance)
- App Store product page — hero screenshot showing library browser with command palette overlay, five sequential screenshots demonstrating capture → annotate → search → AI explain → share workflow
- MacBook Pro lifestyle shot — SnapForge running on a 16-inch MacBook Pro on a minimal oak desk, command palette floating over a code editor, demonstrating the developer workflow context
- Dark mode vs light mode comparison — split-screen showing the full library browser in both appearances, demonstrating that Forge Orange maintains identical vibrancy in both modes
- Command palette close-up — the radial capture launcher floating over a blurred desktop with real app windows beneath, showing the frosted glass material effect and keyboard shortcut hints on each button
- Marketing website hero — centered SnapForge icon at large scale above the logotype, with a single floating screenshot of the app below, on warm linen background with generous whitespace
- Developer documentation header — SnapForge logo lockup with 'HTTP API Reference' subtitle, demonstrating the brand applied to technical documentation contexts
- Shortcuts integration showcase — macOS Shortcuts app with SnapForge actions visible in the action library, showing 'Capture Screenshot', 'Search Library', and 'Explain Screenshot' intents with the forge orange icon
