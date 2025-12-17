using { /Verse.org/Simulation }

tutorial_player_data_class<public> := class<final><persistable>
{
    Inventory<public> : [int]inventory_slot_data = map{}
}

MakePlayerDataClass<constructor>(Source : tutorial_player_data_class)<transacts> := tutorial_player_data_class
{
    Inventory := Source.Inventory
}

tutorial_player_data<public> := module
{
    var PlayerDataMap : weak_map(player, tutorial_player_data_class) = map{}

    LoadPlayer<public>(Player : player) : void =
    {
        if(LoadedPlayerData := PlayerDataMap[Player])
        {
            return
        }

        NewPlayerData := tutorial_player_data_class{}
        (set PlayerDataMap[Player] = NewPlayerData) or Err("Failed to create player data for new player.")
    }

    GetInventoryMap<public>(Player : player)<transacts><decides> : [int]inventory_slot_data =
    {
        return PlayerDataMap[Player].Inventory
    }

    SaveInventorySlot<public>(Player : player, SlotIndex : int, OptionalSlotData : ?inventory_slot_data)<transacts><decides> : void =
    {
        CurrentInventoryMap := GetInventoryMap[Player]

        var NewInventoryMap : [int]inventory_slot_data = map{}
        if(SlotData := OptionalSlotData?)
        {
            set NewInventoryMap = CurrentInventoryMap
            set NewInventoryMap[SlotIndex] = SlotData
        }
        else
        {
            for(OtherSlotIndex -> OtherSlotData : CurrentInventoryMap, OtherSlotIndex <> SlotIndex)
            {
                set NewInventoryMap[OtherSlotIndex] = OtherSlotData
            }
        }

        # update inventory data in player data
        PlayerData := PlayerDataMap[Player]
        set PlayerDataMap[Player] = tutorial_player_data_class
        {
            Inventory := NewInventoryMap
            MakePlayerDataClass<constructor>(PlayerData)
        }
    }
}