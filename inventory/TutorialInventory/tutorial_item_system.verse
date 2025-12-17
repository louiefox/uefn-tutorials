using { /Verse.org/Assets }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }

tutorial_item<public> := class
{
    ItemId<public> : string
    Name<public> : message
    IconTexture<public> : texture
    MaxStackSize<public> : int = 10

    OnItemUsed<public>(TutorialPlayer : tutorial_player) : void =
    {}
}

tutorial_item_heal<public> := class(tutorial_item)
{
    HealAmount<public> : float

    OnItemUsed<override>(TutorialPlayer : tutorial_player) : void =
    {
        if(FortCharacter := TutorialPlayer.Player.GetFortCharacter[])
        {
            FortCharacter.Heal(HealAmount)
        }
    }
}

tutorial_item_shield<public> := class(tutorial_item)
{
    ShieldAmount<public> : float

    OnItemUsed<override>(TutorialPlayer : tutorial_player) : void =
    {
        if(FortCharacter := TutorialPlayer.Player.GetFortCharacter[])
        {
            FortCharacter.SetShield(FortCharacter.GetShield() + ShieldAmount)
        }
    }
}

tutorial_item_damage<public> := class(tutorial_item)
{
    DamageAmount<public> : float

    OnItemUsed<override>(TutorialPlayer : tutorial_player) : void =
    {
        if(FortCharacter := TutorialPlayer.Player.GetFortCharacter[])
        {
            FortCharacter.Damage(DamageAmount)
        }
    }
}

tutorial_item_system<public> := module
{
    ItemApple<localizes> : message = "Apple"
    ItemBattery<localizes> : message = "Battery"
    ItemSkull<localizes> : message = "Skull"

    var ItemsById<internal> : weak_map(session, [string]tutorial_item) = map{}

    CreateItems<public>() : void =
    {
        logic{set ItemsById[GetSession()] = map{}}

        AddItem(tutorial_item_heal{
            ItemId := "apple",
            Name := ItemApple,
            IconTexture := ItemIcons.T_Item_Apple,
            HealAmount := 10.0,
            MaxStackSize := 5
        })

        AddItem(tutorial_item_shield{
            ItemId := "battery",
            Name := ItemBattery,
            IconTexture := ItemIcons.T_Item_Battery,
            ShieldAmount := 25.0,
            MaxStackSize := 1
        })

        AddItem(tutorial_item_damage{
            ItemId := "skull",
            Name := ItemSkull,
            IconTexture := ItemIcons.T_Item_Skull,
            DamageAmount := 15.0
        })
    }

    AddItem<internal>(Item : tutorial_item) : void =
    {
        if(set ItemsById[GetSession()][Item.ItemId] = Item)
        {
            Print("Registered item: {Item.ItemId}")
        }
        else
        {
            Err("Failed to register item with duplicate id: {Item.ItemId}.")
        }
    }

    GetItem<public>(ItemId : string)<transacts><decides> : tutorial_item =
    {
        return ItemsById[GetSession()][ItemId]
    }

    GetItems<public>()<transacts> : []tutorial_item =
    {
        return for(Item : ItemsById[GetSession()]) do Item
    }

    UseItem<public>(TutorialPlayer : tutorial_player, SlotIndex : int) : void =
    {
        if(SlotData := TutorialPlayer.Inventory.GetSlotData[SlotIndex])
        {
            Item := tutorial_item_system.GetItem[SlotData.ItemId] or Err("Failed to get item with id: {SlotData.ItemId}")
            Item.OnItemUsed(TutorialPlayer)

            if(SlotData.Amount > 1)
            {
                TutorialPlayer.Inventory.UpdateSlotData(SlotIndex, inventory_slot_data{
                    ItemId := SlotData.ItemId,
                    Amount := SlotData.Amount - 1
                })
            }
            else
            {
                TutorialPlayer.Inventory.ClearSlotData(SlotIndex)
            }
        }
    }
}