inventory_slot_data<public> := struct<persistable>
{
    ItemId<public> : string
    Amount<public> : int = 1
}

tutorial_inventory<public> := class
{
    InventorySize<public> : int = 20
    OnSlotsUpdated<public> : event([]int) = event([]int){}

    var OptionalOwner<private> : ?tutorial_player = false
    var Slots<private> : [int]inventory_slot_data = map{}

    SetOwner<public>(OptionalTutorialPlayer : ?tutorial_player) : void =
    {
        set OptionalOwner = OptionalTutorialPlayer
    }

    GetOwner<public>()<transacts><decides> : tutorial_player =
    {
        return OptionalOwner?
    }

    InitSlots<public>(SlotsMap : [int]inventory_slot_data) : void =
    {
        set Slots = SlotsMap
    }

    GetSlotData<public>(SlotIndex : int)<transacts><decides> : inventory_slot_data =
    {
        return Slots[SlotIndex]
    }

    UpdateSlotData<public>(SlotIndex : int, SlotData : inventory_slot_data) : void =
    {
        if(set Slots[SlotIndex] = SlotData)
        {
            OnSlotsUpdated.Signal(array{SlotIndex})
        }

        if(Owner := GetOwner[])
        {
            if(tutorial_player_data.SaveInventorySlot[Owner.Player, SlotIndex, option{SlotData}])
            {
                Print("Saved inventory slot data {SlotIndex}, ItemId: {SlotData.ItemId}, Amount: {SlotData.Amount}.")
            }
            else
            {
                Err("Failed to SaveInventorySlot for player, slotIndex: {SlotIndex}.")
            }
        }
    }

    ClearSlotData<public>(SlotIndex : int) : void =
    {
        var NewSlotsMap : [int]inventory_slot_data = map{}
        for(OtherSlotIndex -> OtherSlotData : Slots, OtherSlotIndex <> SlotIndex)
        {
            logic{set NewSlotsMap[OtherSlotIndex] = OtherSlotData}
        }

        set Slots = NewSlotsMap

        OnSlotsUpdated.Signal(array{SlotIndex})

        if(Owner := GetOwner[])
        {
            if(tutorial_player_data.SaveInventorySlot[Owner.Player, SlotIndex, false])
            {
                Print("Saved inventory slot data {SlotIndex} as empty.")
            }
            else
            {
                Err("Failed to SaveInventorySlot for player, slotIndex: {SlotIndex}.")
            }
        }
    }

    CanMergeSlotData<public>(FromSlotData : inventory_slot_data, TargetSlotData : inventory_slot_data)<transacts><decides> : void =
    {
        FromSlotData.ItemId = TargetSlotData.ItemId

        # check if target has space
        Item := tutorial_item_system.GetItem[TargetSlotData.ItemId]
        TargetSlotData.Amount < Item.MaxStackSize
    }

    InsertSlotData<public>(SlotData : inventory_slot_data) : logic =
    {
        var RemainingAmount : int = SlotData.Amount

        # find first available slot
        for(
            SlotIndex := 0..(InventorySize - 1), 
            not Slots[SlotIndex] or CanMergeSlotData[SlotData, Slots[SlotIndex]],
            Item := tutorial_item_system.GetItem[SlotData.ItemId]
        )
        {
            var SlotAmount : int = 0
            if(ExistingSlotData := Slots[SlotIndex])
            {
                set SlotAmount = Min(Item.MaxStackSize, ExistingSlotData.Amount + RemainingAmount)
                set RemainingAmount -= (SlotAmount - ExistingSlotData.Amount)
            }
            else
            {
                set SlotAmount = Min(Item.MaxStackSize, RemainingAmount)
                set RemainingAmount -= SlotAmount
            }

            UpdateSlotData(SlotIndex, inventory_slot_data{
                ItemId := SlotData.ItemId,
                Amount := SlotAmount
            })

            if(RemainingAmount <= 0)
            {
                return true
            }
        }

        return false
    }

    TryMoveItem<public>(FromIndex : int, ToIndex : int) : void =
    {
        if(FromSlotData := GetSlotData[FromIndex], Item := tutorial_item_system.GetItem[FromSlotData.ItemId])
        {
            var OptionalToSlotData : ?inventory_slot_data = option{GetSlotData[ToIndex]}

            if(ToSlotData := OptionalToSlotData?, CanMergeSlotData[FromSlotData, ToSlotData])
            {
                AmountToAdd := Min(Item.MaxStackSize, ToSlotData.Amount + FromSlotData.Amount) - ToSlotData.Amount
                UpdateSlotData(ToIndex, inventory_slot_data{
                    ItemId := ToSlotData.ItemId,
                    Amount := ToSlotData.Amount + AmountToAdd
                })

                AmountRemaining := FromSlotData.Amount - AmountToAdd
                if(AmountRemaining > 0)
                {
                    set OptionalToSlotData = option{inventory_slot_data{
                        ItemId := ToSlotData.ItemId,
                        Amount := AmountRemaining
                    }}
                }
                else
                {
                    set OptionalToSlotData = false
                }
            }
            else
            {
                UpdateSlotData(ToIndex, FromSlotData)
            }

            if(ToSlotData := OptionalToSlotData?)
            {
                UpdateSlotData(FromIndex, ToSlotData)
            }
            else
            {
                ClearSlotData(FromIndex)
            }
        }
    }
}