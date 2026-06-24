defmodule Bandera.Dashboard.Theme do
  @moduledoc """
  Maps a dashboard element's semantic *role* to a CSS class string for the active
  theme. The LiveView markup is identical across themes; only the class strings
  differ, so there is a single template and no fork.

  - `:standalone` (default) returns `bandera-`-prefixed classes styled by the
    inlined stylesheet in `Bandera.Dashboard.Components.styles/1`.
  - `:daisyui` returns daisyUI component classes plus Tailwind layout utilities,
    styled by the host application's own asset build (which must include daisyUI
    and scan Bandera's templates).

  Any theme other than `:daisyui` resolves to the standalone classes.
  """

  @type theme :: :standalone | :daisyui
  @type role ::
          :wrap
          | :heading
          | :flash
          | :flash_warn
          | :search
          | :group
          | :group_summary
          | :count
          | :row
          | :name
          | :full_name
          | :editor
          | :fieldset
          | :legend
          | :gate_list
          | :gate_item
          | :input
          | :select
          | :primary_button
          | :neutral_button
          | :danger_button
          | :icon_button
          | :toggle_on
          | :toggle_off
          | :summary
          | :icon_hint
          | :table
          | :th
          | :td
          | :tr
          | :view_controls
          | :view_toggle_active
          | :view_toggle_inactive
          | :grouping_toggle
          | :create_form
          | :similarity_warning

  @roles ~w(wrap heading flash flash_warn search group group_summary count row name
            full_name editor fieldset legend gate_list gate_item input select
            primary_button neutral_button danger_button icon_button toggle_on
            toggle_off summary icon_hint table th td tr view_controls
            view_toggle_active view_toggle_inactive grouping_toggle create_form
            similarity_warning)a

  @doc "Every semantic role the dashboard styles."
  @spec roles() :: [role]
  def roles, do: @roles

  @doc "The CSS class string for `role` under `theme`."
  @spec class(theme, role) :: String.t()
  def class(:daisyui, role), do: daisyui(role)
  def class(_standalone, role), do: standalone(role)

  defp standalone(:wrap), do: "bandera-wrap"
  defp standalone(:heading), do: "bandera-heading"
  defp standalone(:flash), do: "bandera-flash"
  defp standalone(:search), do: "bandera-search"
  defp standalone(:group), do: "bandera-group"
  defp standalone(:group_summary), do: "bandera-group-summary"
  defp standalone(:count), do: "bandera-count"
  defp standalone(:row), do: "bandera-row"
  defp standalone(:name), do: "bandera-name"
  defp standalone(:editor), do: "bandera-editor"
  defp standalone(:fieldset), do: "bandera-fieldset"
  defp standalone(:legend), do: "bandera-legend"
  defp standalone(:gate_list), do: "bandera-gate-list"
  defp standalone(:gate_item), do: "bandera-gate-item"
  defp standalone(:input), do: "bandera-input"
  defp standalone(:select), do: "bandera-select"
  defp standalone(:primary_button), do: "bandera-primary"
  defp standalone(:neutral_button), do: "bandera-btn"
  defp standalone(:danger_button), do: "bandera-danger"
  defp standalone(:icon_button), do: "bandera-icon-btn"
  defp standalone(:toggle_on), do: "bandera-toggle"
  defp standalone(:toggle_off), do: "bandera-toggle bandera-off"
  defp standalone(:summary), do: "bandera-summary"
  defp standalone(:flash_warn), do: "bandera-flash-warn"
  defp standalone(:icon_hint), do: "bandera-icon-hint"
  defp standalone(:table), do: "bandera-table"
  defp standalone(:th), do: "bandera-th"
  defp standalone(:td), do: "bandera-td"
  defp standalone(:tr), do: "bandera-tr"
  defp standalone(:view_controls), do: "bandera-view-controls"
  defp standalone(:view_toggle_active), do: "bandera-view-toggle bandera-view-toggle--active"
  defp standalone(:view_toggle_inactive), do: "bandera-view-toggle"
  defp standalone(:grouping_toggle), do: "bandera-grouping-toggle"
  defp standalone(:full_name), do: "bandera-full-name"
  defp standalone(:create_form), do: "bandera-create-form"
  defp standalone(:similarity_warning), do: "bandera-similarity-warning"

  defp daisyui(:wrap), do: "max-w-3xl mx-auto p-4"
  defp daisyui(:heading), do: "text-xl font-bold mb-4"
  defp daisyui(:flash), do: "alert alert-error mb-3"
  defp daisyui(:search), do: "input input-bordered w-full mb-4"
  defp daisyui(:group), do: "mb-2"
  defp daisyui(:group_summary), do: "cursor-pointer font-semibold text-primary py-1 select-none"
  defp daisyui(:count), do: "text-base-content/50 font-normal ml-1"

  defp daisyui(:row),
    do:
      "flex items-center justify-between rounded-box border border-base-300 bg-base-100 px-3 py-2 my-1.5"

  defp daisyui(:name), do: "font-semibold"
  defp daisyui(:editor), do: "rounded-box border border-base-300 bg-base-200 p-3 mb-2"
  defp daisyui(:fieldset), do: "border border-dashed border-base-300 rounded-box my-2 p-3"
  defp daisyui(:legend), do: "text-xs uppercase tracking-wide text-base-content/50 px-1"
  defp daisyui(:gate_list), do: "list-none p-0 mt-2 space-y-1"
  defp daisyui(:gate_item), do: "flex items-center gap-2"
  defp daisyui(:input), do: "input input-bordered input-sm"
  defp daisyui(:select), do: "select select-bordered select-sm"
  defp daisyui(:primary_button), do: "btn btn-primary btn-sm"
  defp daisyui(:neutral_button), do: "btn btn-ghost btn-sm"
  defp daisyui(:danger_button), do: "btn btn-error btn-outline btn-sm"
  defp daisyui(:icon_button), do: "btn btn-ghost btn-xs"
  defp daisyui(:toggle_on), do: "btn btn-success btn-sm"
  defp daisyui(:toggle_off), do: "btn btn-sm"
  defp daisyui(:summary), do: "text-base-content/60 text-sm ml-2"
  defp daisyui(:flash_warn), do: "alert alert-warning mb-3"
  defp daisyui(:icon_hint), do: "text-sm ml-1"
  defp daisyui(:table), do: "table table-zebra w-full"
  defp daisyui(:th), do: "th"
  defp daisyui(:td), do: "td"
  defp daisyui(:tr), do: "tr"
  defp daisyui(:view_controls), do: "flex gap-4 items-center mb-4 text-sm"
  defp daisyui(:view_toggle_active), do: "btn btn-sm btn-primary"
  defp daisyui(:view_toggle_inactive), do: "btn btn-sm btn-ghost"
  defp daisyui(:grouping_toggle), do: "text-base-content/60 cursor-pointer"
  defp daisyui(:full_name), do: "text-xs text-base-content/40 mt-0.5 block"
  defp daisyui(:create_form), do: "flex gap-2 items-center mb-4"
  defp daisyui(:similarity_warning), do: "alert alert-warning mb-3"
end
