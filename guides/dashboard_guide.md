# Bandera Flag Dashboard

Bandera ships an optional LiveView dashboard for browsing and managing flags. It
lives in the core library but is inert unless your app depends on
`phoenix_live_view`. It ships **no JavaScript** and needs **no asset-pipeline
changes**: it inherits your app's layout and runs on your existing LiveView
socket.

## Setup

1. Add LiveView to your deps (you almost certainly already have it):

   ```elixir
   {:phoenix_live_view, "~> 1.0"}
   ```

2. Mount it in your router **behind your own auth pipeline**:

   ```elixir
   import Bandera.Dashboard.Router

   scope "/admin" do
     pipe_through [:browser, :require_admin]   # YOUR authentication/authorization
     bandera_dashboard "/flags"
   end
   ```

   The dashboard can toggle production features. **Never** mount it on an
   unauthenticated route.

The dashboard sets no root layout — it inherits the one from your pipeline — and
relies on your app's `app.js` / `LiveSocket` for interactivity. Mount it under a
pipeline whose layout loads `app.js` (the default `:browser` pipeline does). By
default its CSS is self-contained and inlined, with `bandera-`-prefixed selectors,
so it won't clash with your styles. See [Theming](#theming) to retheme it or to
switch to daisyUI.

## Grouping

Flags are grouped by a name-prefix convention: the part of the flag's name before
the first separator is the group. The separator defaults to `"_"`:

```elixir
config :bandera, dashboard: [group_separator: "_"]
```

So `:billing_checkout_v2` and `:billing_invoices` appear under **billing**. Flags
with no separator (e.g. `:beta`) appear under **Ungrouped**. Set
`group_separator: nil` to disable grouping.

## Theming

The dashboard has two themes, chosen by config:

```elixir
config :bandera, dashboard: [theme: :standalone]   # default
```

### `:standalone` (default)

A self-contained, inlined stylesheet with `bandera-`-prefixed selectors. No asset
pipeline, no daisyUI, no clashes. Colors, radii, and fonts are read as CSS custom
properties with built-in fallbacks, so you can retheme with a single rule — no
specificity battles, no `!important`:

```css
:root {
  --bandera-primary: #0ea5e9;     /* buttons, group headers, focus rings */
  --bandera-radius: 6px;          /* cards and inputs */
  --bandera-surface: #ffffff;     /* card background */
  --bandera-border: #e2e8f0;
  /* also: --bandera-fg, --bandera-muted, --bandera-surface-2,
     --bandera-radius-sm, --bandera-shadow, --bandera-primary-fg,
     --bandera-success, --bandera-off, --bandera-danger,
     --bandera-danger-border, --bandera-danger-bg, --bandera-font */
}
```

The defaults are a fixed light palette. For dark mode, set the variables (e.g.
inside your own `@media (prefers-color-scheme: dark)`), or use the `:daisyui`
theme below.

### `:daisyui`

```elixir
config :bandera, dashboard: [theme: :daisyui]
```

In this mode the dashboard emits daisyUI component classes (`btn`, `input`,
`select`, `alert`, …) and **no** inlined `<style>`, so it inherits your app's daisyUI theme
(including dark mode and brand colors). This requires your app to build daisyUI
itself, and — because Bandera ships compiled templates that Tailwind doesn't scan
by default — you must add Bandera to your Tailwind sources so the classes are
generated:

```css
/* assets/css/app.css (Tailwind v4 / Phoenix 1.8) */
@source "../../deps/bandera/lib";
```

(Tailwind v3: add `"../deps/bandera/lib/**/*.ex"` to `content` in
`tailwind.config.js`.) Without this, the dashboard renders unstyled.

## Live updates across nodes

If you've configured Bandera's `PhoenixPubSub` cache-bust notifications, open
dashboards refresh automatically when another node or operator changes a flag.

## What you can manage

Per flag: the boolean on/off toggle, per-actor gates, per-group gates, and a
percentage rollout (of actors or of time), plus clearing the whole flag. Search
filters the list as you type. (Creating brand-new flags from the UI is not in this
version — flags are created in code/IEx via `Bandera.enable/2`.)
