using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Assets }
using { /Verse.org/Colors }
using { /Verse.org/Random }
using { /Fortnite.com/UI }

ui_anchors<public> := struct
{
    TopLeft<public> : vector2 = vector2{ X := 0.0, Y := 0.0 }
    BottomRight<public> : vector2 = vector2{ X := 1.0, Y := 1.0 }
    Center<public> : vector2 = vector2{ X := 0.5, Y := 0.5 }
}

inventory_menu<public> := class
{
    Owner<public> : tutorial_player

    Anchors : ui_anchors = ui_anchors{}
    Canvas : canvas = canvas{}
    ActionButtonRow : stack_box = stack_box{ Orientation := orientation.Horizontal }

    CloseMessage<localizes> : message = "Close Menu"
    UseItemMessage<localizes> : message = "Use"
    InsertRandomMessage<localizes> : message = "Insert"

    var SlotWidgets<private> : []inventory_slot_widget = array{}
    var ActionButtons<private> : []text_button_base = array{}
    var OptionalSelectedSlotIndex<private> : ?int = false
    var OptionalUseItemButton<private> : ?text_button_base = false

    SetupWidget<public>() : void =
    {
        # background
        BackgroundWidget := color_block{
            DefaultColor := NamedColors.Black,
            DefaultOpacity := 0.8
        }

        Canvas.AddWidget(canvas_slot{
            Widget := BackgroundWidget,
            Anchors := anchors{ Minimum := Anchors.TopLeft, Maximum := Anchors.BottomRight }
        })

        # inventory column
        ColumnWidget := stack_box{
            Orientation := orientation.Vertical
        }

        Canvas.AddWidget(canvas_slot{
            Widget := ColumnWidget,
            Anchors := anchors{ Minimum := Anchors.Center, Maximum := Anchors.Center },
            Alignment := vector2{ X := 0.5, Y := 0.5 }
        })

        # inventory grid
        SlotsPerRow := 5
        RowCount := Ceil(Owner.Inventory.InventorySize / SlotsPerRow) or 0
        SlotMargin := 10.0

        for(Row := 0..(RowCount - 1))
        {
            RowWidget := stack_box{ Orientation := orientation.Horizontal }
            ColumnWidget.AddWidget(stack_box_slot{
                Widget := RowWidget,
                HorizontalAlignment := horizontal_alignment.Left,
                Padding := margin{ Left := 0.0, Top := (Row > 0) and SlotMargin or 0.0, Right := 0.0, Bottom := 0.0 }
            })

            for(Column := 0..(SlotsPerRow - 1))
            {
                SlotIndex := (Row * SlotsPerRow) + Column

                SlotWidget := inventory_slot_widget{ ParentInventoryMenu := Self, SlotIndex := SlotIndex }
                SlotWidget.SetupWidget()

                RowWidget.AddWidget(stack_box_slot{
                    Widget := SlotWidget.GetWidget(),
                    HorizontalAlignment := horizontal_alignment.Left,
                    Padding := margin{ Left := (Column > 0) and SlotMargin or 0.0, Top := 0.0, Right := 0.0, Bottom := 0.0 }
                })

                set SlotWidgets += array{SlotWidget}
            }
        }

        UpdateSlotData()
        spawn{CreateInventoryEventListeners()}

        # action buttons
        ColumnWidget.AddWidget(stack_box_slot{
            Widget := ActionButtonRow,
            HorizontalAlignment := horizontal_alignment.Fill,
            Padding := margin{ Left := 0.0, Top := 10.0, Right := 0.0, Bottom := 0.0 }
        })

        UseItemButton := CreateActionButton(UseItemMessage)
        UseItemButton.SetEnabled(false)
        UseItemButton.OnClick().Subscribe(OnUseItemButtonPressed)

        set OptionalUseItemButton = option{UseItemButton}

        InsertItemButton := CreateActionButton(InsertRandomMessage)
        InsertItemButton.OnClick().Subscribe(OnInsertItemButtonPressed)

        # close button
        CloseButtonWidget := button_quiet{
            DefaultText := CloseMessage
        }

        CloseButtonWidget.OnClick().Subscribe(OnCloseButtonPressed)

        ColumnWidget.AddWidget(stack_box_slot{
            Widget := CloseButtonWidget,
            HorizontalAlignment := horizontal_alignment.Fill,
            Padding := margin{ Left := 0.0, Top := 25.0, Right := 0.0, Bottom := 0.0 }
        })
    }

    GetWidget<public>() : widget =
    {
        return Canvas
    }

    Open<public>() : void =
    {
        if(PlayerUI := GetPlayerUI[Owner.Player])
        {
            PlayerUI.AddWidget(GetWidget(), player_ui_slot{ InputMode := ui_input_mode.All })
        }
    }

    Close<public>() : void =
    {
        if(PlayerUI := GetPlayerUI[Owner.Player])
        {
            PlayerUI.RemoveWidget(GetWidget())
        }
    }

    OnCloseButtonPressed<private>(WidgetMessage : widget_message) : void =
    {
        Close()
    }

    UpdateSlotData<private>(?ModifiedSlotIndicies : ?[]int = false) : void =
    {
        var SlotIndicesToUpdate : []int = ModifiedSlotIndicies? or array{}
        if(not ModifiedSlotIndicies?)
        {
            set SlotIndicesToUpdate = for(SlotIndex := 0..(Owner.Inventory.InventorySize - 1)) do SlotIndex
        }

        for(SlotIndex : SlotIndicesToUpdate, SlotWidget := SlotWidgets[SlotIndex])
        {
            OptionalSlotData := option{Owner.Inventory.GetSlotData[SlotIndex]}
            SlotWidget.SetSlotData(OptionalSlotData)

            # de-select slot if currently selected
            if(OptionalSelectedSlotIndex? = SlotIndex, not OptionalSlotData?)
            {
                SetSelectedSlot(false)
            }
        }
    }

    CreateInventoryEventListeners<private>()<suspends> : void =
    {
        race
        {
            Owner.OnPlayerRemoved.Await()

            loop
            {
                ModifiedSlotIndicies := Owner.Inventory.OnSlotsUpdated.Await()
                UpdateSlotData(?ModifiedSlotIndicies := option{ModifiedSlotIndicies})
            }
        }
    }

    CreateActionButton<private>(ButtonText : message) : text_button_base =
    {
        ButtonWidget := button_quiet{
            DefaultText := ButtonText
        }

        ActionButtonRow.AddWidget(stack_box_slot{
            Widget := ButtonWidget,
            HorizontalAlignment := horizontal_alignment.Fill,
            Distribution := option{1.0},
            Padding := margin{ Left := (ActionButtons.Length > 0) and 10.0 or 0.0, Top := 0.0, Right := 0.0, Bottom := 0.0 }
        })

        set ActionButtons += array{ButtonWidget}

        return ButtonWidget
    }

    OnUseItemButtonPressed<private>(WidgetMessage : widget_message) : void =
    {
        if(SelectedSlotIndex := OptionalSelectedSlotIndex?)
        {
            tutorial_item_system.UseItem(Owner, SelectedSlotIndex)
        }
    }

    OnInsertItemButtonPressed<private>(WidgetMessage : widget_message) : void =
    {
        ItemsArray := tutorial_item_system.GetItems()
        if(RandomItem := ItemsArray[GetRandomInt(0, ItemsArray.Length - 1)])
        {
            Success := Owner.Inventory.InsertSlotData(inventory_slot_data{
                ItemId := RandomItem.ItemId
            })

            if(not Success?)
            {
                Print("Failed to insert random item into inventory.")
            }
        }
        else
        {
            Print("Failed to get random item from array.")
        }
    }

    OnSlotPressed<public>(SlotIndex : int) : void =
    {
        SlotWidget := SlotWidgets[SlotIndex] or Err("Invalid slot index passed to OnSlotPressed: {SlotIndex}.")

        if(SelectedSlotIndex := OptionalSelectedSlotIndex?)
        {
            # attempt to move/swap slots
            if(SelectedSlotIndex <> SlotIndex)
            {
                Owner.Inventory.TryMoveItem(SelectedSlotIndex, SlotIndex)
            }

            SetSelectedSlot(false)
        }
        else if(Owner.Inventory.GetSlotData[SlotIndex]) # only select if slot has data
        {
            # select pressed slot index
            SetSelectedSlot(option{SlotIndex})
        }
    }

    SetSelectedSlot<private>(OptionalSlotIndex : ?int) : void =
    {
        # de-select current slot
        if(SelectedSlotIndex := OptionalSelectedSlotIndex?, SlotWidget := SlotWidgets[SelectedSlotIndex])
        {
            set OptionalSelectedSlotIndex = false
            SlotWidget.SetSelected(false)
        }

        # select new slot
        if(SlotIndex := OptionalSlotIndex?, SlotWidget := SlotWidgets[SlotIndex])
        {
            set OptionalSelectedSlotIndex = option{SlotIndex}
            SlotWidget.SetSelected(true)
        }

        # update use item button enabled
        if(UseItemButton := OptionalUseItemButton?)
        {
            UseItemButton.SetEnabled(logic{OptionalSelectedSlotIndex?})
        }
    }
}

inventory_slot_widget<public> := class
{
    ParentInventoryMenu<public> : inventory_menu
    SlotIndex<public> : int

    AmountMessage<localizes>(Amount : int) : message = "{Amount}"

    Overlay : overlay = overlay{}

    SlotBackgroundWidget : color_block = color_block{
        DefaultColor := NamedColors.Black,
        DefaultOpacity := 0.75,
        DefaultDesiredSize := vector2{ X := 75.0, Y := 75.0 }
    }

    IconWidget : texture_block = texture_block{
        DefaultImage := ItemIcons.T_Item_Apple,
        DefaultDesiredSize := vector2{ X := 64.0, Y := 64.0 }
    }

    AmountTextWidget : text_block = text_block{
        DefaultTextColor := NamedColors.White,
        DefaultShadowColor := NamedColors.Black,
        DefaultShadowOpacity := 1.0,
        DefaultShadowOffset := option{vector2{ X := 2.0, Y := 2.0 }}
    }

    SetupWidget<public>() : void =
    {
        # slot background
        Overlay.AddWidget(overlay_slot{ Widget := SlotBackgroundWidget })

        # item icon
        IconWidget.SetVisibility(widget_visibility.Hidden)
        Overlay.AddWidget(overlay_slot{
            Widget := IconWidget,
            HorizontalAlignment := horizontal_alignment.Center,
            VerticalAlignment := vertical_alignment.Center
        })

        # item amount text
        AmountTextWidget.SetVisibility(widget_visibility.Hidden)
        Overlay.AddWidget(overlay_slot{
            Widget := AmountTextWidget,
            HorizontalAlignment := horizontal_alignment.Right,
            VerticalAlignment := vertical_alignment.Bottom
        })

        # slot button
        ButtonWidget := button_quiet{}
        ButtonWidget.OnClick().Subscribe(OnButtonPressed)

        Overlay.AddWidget(overlay_slot{
            Widget := ButtonWidget,
            HorizontalAlignment := horizontal_alignment.Fill,
            VerticalAlignment := vertical_alignment.Fill
        })
    }

    GetWidget<public>() : widget =
    {
        return Overlay
    }

    OnButtonPressed<private>(WidgetMessage : widget_message) : void =
    {
        ParentInventoryMenu.OnSlotPressed(SlotIndex)
    }

    SetSlotData<public>(OptionalSlotData : ?inventory_slot_data) : void =
    {
        if(SlotData := OptionalSlotData?)
        {
            Item := tutorial_item_system.GetItem[SlotData.ItemId] or Err("Failed to get item with id: {SlotData.ItemId}")

            IconWidget.SetVisibility(widget_visibility.Visible)
            IconWidget.SetImage(Item.IconTexture)

            AmountTextWidget.SetVisibility(Item.MaxStackSize > 1 and widget_visibility.Visible or widget_visibility.Hidden)
            AmountTextWidget.SetText(AmountMessage(SlotData.Amount))
        }
        else
        {
            IconWidget.SetVisibility(widget_visibility.Hidden)
            AmountTextWidget.SetVisibility(widget_visibility.Hidden)
        }
    }

    SetSelected<public>(IsSelected : logic) : void =
    {
        SlotBackgroundWidget.SetColor(IsSelected? and NamedColors.White or NamedColors.Black)
    }
}