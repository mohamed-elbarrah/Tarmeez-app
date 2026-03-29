TARMEEZ SAAS: ARCHITECTURAL MANIFESTO & COMPLIANCE CHARTER
I. THE "HYBRID" COMMANDMENTS (Structural Rules)

    Strict Separation of Concerns (SoC):

        Logic (The Brain): Use OOP Singletons and Services for data fetching, business rules, and state management.

        Presentation (The Body): Use Functional React Components as "Dumb Widgets". They only know how to render what they receive via Props.

    Contract-Driven Development:

        Every Theme-specific component must implement a predefined TypeScript Interface. If a theme wants to override ProductCard, it must strictly adhere to IProductCardProps.

    The Fallback Hierarchy (Inheritance):

        The system must always look for a component in this order: Active Theme Overrides -> Organization/Activity Defaults -> System Default Theme. Never fail if a specific theme file is missing.

    Widget Serialization Ready:

        All UI components must be "Serializable". This means they must function correctly when their configuration is passed as a flat JSON object (crucial for the future Drag-and-Drop Page Builder).

II. THE "DOs" (Best Practices for 2026)

    DO use Custom Hooks as the ONLY bridge between UI components and OOP Services (e.g., const { data } = useService(CartService)).

    DO implement Slot-based Composition. Instead of huge components, use children or renderProps to inject theme-specific elements (like the Donation Progress Bar).

    DO utilize CSS Variables (Design Tokens) for all styling. The Theme Engine should inject values into :root, and Tailwind should consume them.

    DO ensure Atomic Design. Build small, reusable atoms (Buttons, Badges) before building complex organisms (ProductCards).

III. THE "DONTs" (Forbidden Anti-Patterns)

    NEVER use if/else based on storeType or activityType inside a JSX return. Use Component Swapping or Higher-Order Components (HOCs) instead.

    NEVER allow a UI component to perform a direct fetch or axios call. This creates a "Tight Coupling" that kills flexibility.

    NEVER hardcode localized strings. Use a Localization Provider that fetches the correct terminology (e.g., "Donation" vs "Order") based on the activityType.

    NEVER use "Magic Numbers" or "Hardcoded Hex Colors". Everything must reference a Theme Token.

IV. THE DEVOPS & SCALABILITY STANDARDS

    Tree-Shaking First: Ensure that loading the "Charity Theme" does not bundle code from the "Restaurant Theme".

    Zero Layout Shift (CLS): Components must have reserved dimensions or skeleton states to ensure a premium user experience during hydration.

    Strict Prop Validation: Every Widget must have a schema definition (Zod or JSON Schema) to validate the data passed by the Page Builder.
