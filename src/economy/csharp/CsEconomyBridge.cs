using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

namespace Condor.Economy;

/// <summary>
/// Godot Node bridge between GDScript economy shell and C# inner engine.
/// GDScript calls this node's methods; it translates between GDScript Resources
/// and C# flat-array engine, runs the tick, and returns results.
///
/// Usage from GDScript:
///   var bridge = CsEconomyBridge.new()
///   bridge.setup(world)          # mirrors GDScript data into C#
///   var result = bridge.tick(turn) # returns a Dictionary with tick results
/// </summary>
[GlobalClass]
public partial class CsEconomyBridge : Node
{
    private CsEconomyEngine _engine;

    // Mapping between GDScript index-space and C# index-space
    private ThingDef[] _goods;
    private CsLocationData[] _locations;
    private System.Collections.Generic.Dictionary<string, int> _thingIdToIdx = new();
    private System.Collections.Generic.Dictionary<string, int> _locationIdToIdx = new();

    // Stored reference to GDScript world for travel time queries
    private GodotObject _world;

    // Bank config (now applied to the imperial government)
    private float _bankInterestRate = 0.08f;
    private float _bankPrintPerTurn = 500f;
    private float _nobleLoanThreshold = 100f;
    private float _loanAmount = 500f;
    private bool _usesBank;

    /// <summary>
    /// Initialize the C# engine from GDScript World data.
    /// Called once at setup time.
    /// </summary>
    public void Setup(GodotObject world)
    {
        _world = world;

        // Read goods from world.goods (Array of Thing Resources)
        var gdGoods = (Godot.Collections.Array)world.Get("goods");
        _goods = new ThingDef[gdGoods.Count];
        _thingIdToIdx.Clear();

        for (int i = 0; i < gdGoods.Count; i++)
        {
            var thing = (Resource)gdGoods[i];
            string thingId = (string)thing.Get("thing_id");
            string thingName = (string)thing.Get("thing_name");
            int thingType = (int)thing.Get("thing_type");
            float basePrice = (float)thing.Get("base_price");
            _goods[i] = new ThingDef(i, thingId, thingName, (ThingType)thingType, basePrice);
            _thingIdToIdx[thingId] = i;

            // Mirror elasticity
            float elasticity = (float)thing.Call("get_elasticity");
            _goods[i].Elasticity = elasticity;
        }

        // Second pass: mirror inputs (after all goods are indexed)
        for (int i = 0; i < gdGoods.Count; i++)
        {
            var thing = (Resource)gdGoods[i];
            var gdInputs = (Godot.Collections.Array)thing.Get("inputs");
            if (gdInputs != null && gdInputs.Count > 0)
            {
                var inputs = new RecipeInput[gdInputs.Count];
                for (int ii = 0; ii < gdInputs.Count; ii++)
                {
                    var gdInput = (Resource)gdInputs[ii];
                    var inputThing = (Resource)gdInput.Get("thing");
                    string inputThingId = (string)inputThing.Get("thing_id");
                    float inputQty = (float)gdInput.Get("quantity");
                    inputs[ii] = new RecipeInput
                    {
                        ThingIdx = _thingIdToIdx[inputThingId],
                        Quantity = inputQty,
                    };
                }
                _goods[i].Inputs = inputs;
            }
        }

        // Read economy locations
        var gdLocations = (Godot.Collections.Array)world.Call("get_economy_locations");
        _locations = new CsLocationData[gdLocations.Count];
        _locationIdToIdx.Clear();

        for (int li = 0; li < gdLocations.Count; li++)
        {
            var gdLoc = (Resource)gdLocations[li];
            string locId = (string)gdLoc.Get("location_id");
            string locName = (string)gdLoc.Get("location_name");
            _locationIdToIdx[locId] = li;

            var csLoc = new CsLocationData(_goods.Length)
            {
                Idx = li,
                LocationId = locId,
                LocationName = locName,
                Population = new CsPopulation(),
            };
            _locations[li] = csLoc;
        }

        // Second pass: populate populations, inventories, supply rules
        for (int li = 0; li < gdLocations.Count; li++)
        {
            var gdLoc = (Resource)gdLocations[li];
            var csLoc = _locations[li];

            // Mirror population
            var gdPop = (GodotObject)gdLoc.Get("population");
            var gdPeople = (Godot.Collections.Array)gdPop.Get("people");
            for (int pi = 0; pi < gdPeople.Count; pi++)
            {
                var gdPerson = (GodotObject)gdPeople[pi];
                var csPerson = MirrorPerson(gdPerson);
                csLoc.Population.AddPerson(csPerson);
            }

            // Mirror inventory stocks
            var gdInv = (Resource)gdLoc.Get("inventory");
            // Force initialization by calling get_available on a dummy
            gdInv.Call("_ensure_initialized");
            var gdStocks = (Godot.Collections.Dictionary)gdInv.Get("stocks");
            foreach (var kv in gdStocks)
            {
                var thing = (Resource)kv.Key;
                string thingId = (string)thing.Get("thing_id");
                if (_thingIdToIdx.TryGetValue(thingId, out int idx))
                    csLoc.Stocks[idx] = (float)kv.Value;
            }
            // Mirror prices
            var gdPrices = (Godot.Collections.Dictionary)gdInv.Get("prices");
            foreach (var kv in gdPrices)
            {
                var thing = (Resource)kv.Key;
                string thingId = (string)thing.Get("thing_id");
                if (_thingIdToIdx.TryGetValue(thingId, out int idx))
                    csLoc.Prices[idx] = (float)kv.Value;
            }
            // Initialize missing prices from base_price
            for (int gi = 0; gi < _goods.Length; gi++)
            {
                if (csLoc.Prices[gi] == 0f)
                    csLoc.Prices[gi] = _goods[gi].BasePrice;
            }

            // Mirror natural resources
            var gdResources = (Godot.Collections.Array)gdLoc.Get("natural_resources");
            for (int ri = 0; ri < gdResources.Count; ri++)
            {
                var gdRes = (Resource)gdResources[ri];
                var csRes = new CsNaturalResource
                {
                    BaseCapacity = (float)gdRes.Get("base_capacity"),
                    WorkerJob = (JobType)(int)gdRes.Get("worker_job"),
                    WorkersNeeded = (float)gdRes.Get("workers_needed"),
                };
                var resThing = (Resource)gdRes.Get("thing");
                string resThingId = (string)resThing.Get("thing_id");
                csRes.ThingIdx = _thingIdToIdx[resThingId];
                csLoc.NaturalResources.Add(csRes);
            }

            // Mirror government config; flag imperial location based on Location.is_imperial
            var govConfig = gdLoc.Get("government_config");
            bool isImperial = false;
            var imperialField = gdLoc.Get("is_imperial");
            if (imperialField.VariantType != Variant.Type.Nil)
                isImperial = (bool)imperialField;
            if (govConfig.VariantType != Variant.Type.Nil)
            {
                var gdGov = (Resource)govConfig;
                var csGov = new CsGovernment
                {
                    LocationIndex = li,
                    LocationId = csLoc.LocationId,
                    TaxRate = (double)(float)gdGov.Get("tax_rate"),
                    MaxBudgetRatio = (float)gdGov.Get("max_budget_ratio"),
                    PushWeight = (float)gdGov.Get("push_weight"),
                    PullWeight = (float)gdGov.Get("pull_weight"),
                    Treasury = (double)(float)gdGov.Get("starting_treasury"),
                    IsImperial = isImperial,
                };
                var priorityGoods = (Godot.Collections.Array)gdGov.Get("priority_goods");
                for (int gi = 0; gi < priorityGoods.Count; gi++)
                {
                    string goodId = (string)priorityGoods[gi];
                    if (_thingIdToIdx.TryGetValue(goodId, out int goodIdx))
                        csGov.PriorityGoodIndices.Add(goodIdx);
                }
                csLoc.Government = csGov;
            }
            else if (isImperial)
            {
                // Location flagged imperial but no GovernmentConfig.tres — synthesize one.
                csLoc.Government = new CsGovernment
                {
                    LocationIndex = li,
                    LocationId = csLoc.LocationId,
                    IsImperial = true,
                };
            }

            // Mirror guild configs
            var guildConfigs = gdLoc.Get("guild_configs");
            if (guildConfigs.VariantType != Variant.Type.Nil)
            {
                var gdGuilds = guildConfigs.As<Godot.Collections.Array>();
                if (gdGuilds != null && gdGuilds.Count > 0)
                {
                    var guildList = new List<CsGuild>();
                    for (int gci = 0; gci < gdGuilds.Count; gci++)
                    {
                        var gdGuild = (Resource)gdGuilds[gci];
                        var specsVariant = gdGuild.Get("specializations");
                        if (specsVariant.VariantType == Variant.Type.Nil) continue;
                        var gdSpecs = specsVariant.As<Godot.Collections.Array>();
                        if (gdSpecs == null || gdSpecs.Count == 0) continue;

                        var csSpecs = new List<CsGuildSpecialization>();
                        for (int si = 0; si < gdSpecs.Count; si++)
                        {
                            var gdSpec = gdSpecs[si].As<Resource>();
                            if (gdSpec == null) continue;
                            var specThing = gdSpec.Get("thing").As<Resource>();
                            if (specThing == null) continue;
                            string thingId = (string)specThing.Get("thing_id");
                            if (!_thingIdToIdx.TryGetValue(thingId, out int thingIdx)) continue;
                            var gdWorkerJob = gdSpec.Get("worker_job");
                            csSpecs.Add(new CsGuildSpecialization
                            {
                                ThingIdx = thingIdx,
                                MaxEfficiencyWorkers = (int)gdSpec.Get("max_workers"),
                                WorkerJob = gdWorkerJob.VariantType != Variant.Type.Nil
                                    ? (JobType)(int)gdWorkerJob : JobType.Craftsman,
                                WagePerWorker = (float)gdSpec.Get("wage_per_worker"),
                                RecruitmentRate = (int)gdSpec.Get("recruitment_rate"),
                            });
                        }
                        if (csSpecs.Count == 0) continue;

                        guildList.Add(new CsGuild
                        {
                            LocationIndex = li,
                            LocationId = csLoc.LocationId,
                            GuildName = (string)gdGuild.Get("guild_name"),
                            Specializations = csSpecs.ToArray(),
                            Treasury = (double)(float)gdGuild.Get("starting_treasury"),
                        });
                    }
                    if (guildList.Count > 0)
                        csLoc.Guilds = guildList;
                }
            }
        }

        // Populate Actors: guild_configs guilds, auto-create extraction guilds for
        // uncovered natural resources, then add Government + Geist pointers.
        for (int li = 0; li < _locations.Length; li++)
        {
            var csLoc = _locations[li];

            // Add guild configs to Actors
            if (csLoc.Guilds != null)
            {
                for (int gi = 0; gi < csLoc.Guilds.Count; gi++)
                {
                    csLoc.Guilds[gi].SetGoods(_goods);
                    csLoc.Actors.Add(csLoc.Guilds[gi]);
                }
            }

            // Auto-create extraction guilds for uncovered natural resources
            foreach (var res in csLoc.NaturalResources)
            {
                bool covered = false;
                for (int ai = 0; ai < csLoc.Actors.Count; ai++)
                {
                    if (csLoc.Actors[ai] is CsGuild g && CoveredByGuild(g, res.ThingIdx))
                    { covered = true; break; }
                }
                if (!covered)
                {
                    var extractionGuild = new CsGuild
                    {
                        LocationIndex = li,
                        LocationId = csLoc.LocationId,
                        GuildName = $"{csLoc.LocationName} {_goods?[res.ThingIdx]?.ThingName ?? "Good"} Extractors",
                        Specializations = new[] { new CsGuildSpecialization
                        {
                            ThingIdx = res.ThingIdx,
                            MaxEfficiencyWorkers = (int)res.WorkersNeeded,
                            WorkerJob = res.WorkerJob,
                            WagePerWorker = 0.5f,
                            RecruitmentRate = 2,
                        }},
                        Treasury = 50.0,
                    };
                    extractionGuild.SetGoods(_goods);
                    csLoc.Actors.Add(extractionGuild);
                }
            }

            if (csLoc.Government != null && !csLoc.Actors.Contains(csLoc.Government))
                csLoc.Actors.Add(csLoc.Government);
            if (csLoc.Geist != null && !csLoc.Actors.Contains(csLoc.Geist))
                csLoc.Actors.Add(csLoc.Geist);
        }

        // Create engine
        _engine = new CsEconomyEngine();
        _engine.Initialize(_goods, _locations);
        _engine.NobleLoanThreshold = _nobleLoanThreshold;
        _engine.LoanAmount = _loanAmount;
        _engine._locationIdToIdx = _locationIdToIdx;
        _engine._thingIdToIdx = _thingIdToIdx;

        // Travel time callback via GDScript world (returns hours at default caravan speed)
        _engine.GetTravelTimeFunc = (fromIdx, toIdx) =>
        {
            string fromId = _locations[fromIdx].LocationId;
            string toId = _locations[toIdx].LocationId;
            return (int)_world.Call("calculate_travel_hours", fromId, toId, 3.0f);
        };
    }

    /// <summary>
    /// Configure imperial-bank parameters. Applies them to the engine's
    /// imperial government (the location flagged is_imperial). If no imperial
    /// government has been declared, falls back to the first government found —
    /// preserves legacy single-bank semantics for tests built on the old API.
    /// </summary>
    public void SetupBank(float interestRate = 0.08f, float printPerTurn = 500f,
        float nobleLoanThreshold = 100f, float loanAmount = 500f)
    {
        _bankInterestRate = interestRate;
        _bankPrintPerTurn = printPerTurn;
        _nobleLoanThreshold = nobleLoanThreshold;
        _loanAmount = loanAmount;
        _usesBank = true;

        if (_engine == null) return;

        var imperial = _engine.ImperialGovernment;
        if (imperial == null)
        {
            // Legacy fallback: promote first government to imperial.
            for (int li = 0; li < _engine.Locations.Length; li++)
            {
                if (_engine.Locations[li].Government != null)
                {
                    _engine.Locations[li].Government.IsImperial = true;
                    imperial = _engine.Locations[li].Government;
                    break;
                }
            }
        }
        if (imperial != null)
        {
            imperial.LoanInterestRate = interestRate;
            imperial.PrintPerTurn = printPerTurn;
        }
        _engine.NobleLoanThreshold = nobleLoanThreshold;
        _engine.LoanAmount = loanAmount;
    }

    /// <summary>
    /// Run one economy tick with a pre-computed inter-location danger matrix
    /// (NxN, indexed by world.get_economy_locations() order, values in 0..1).
    /// Returns a Dictionary with results (snapshots, deaths, births,
    /// moves_created, moves_completed, shipment_dispatches) ready for GDScript.
    /// </summary>
    public Godot.Collections.Dictionary Tick(int turn, Godot.Collections.Array dangerRows = null)
    {
        float[,] matrix = null;
        if (dangerRows != null && dangerRows.Count > 0)
        {
            int n = _locations.Length;
            matrix = new float[n, n];
            int rows = Math.Min(dangerRows.Count, n);
            for (int i = 0; i < rows; i++)
            {
                var row = dangerRows[i].As<Godot.Collections.Array>();
                if (row == null) continue;
                int cols = Math.Min(row.Count, n);
                for (int j = 0; j < cols; j++)
                {
                    matrix[i, j] = (float)(double)row[j];
                }
            }
        }
        var csResult = _engine.Tick(turn, matrix);
        _lastTickResult = csResult;
        return ConvertResult(csResult);
    }

    private CsEconomyTickResult _lastTickResult;

    /// <summary>
    /// Fast sync: only writes location-level inventory stocks and prices back.
    /// This is O(locations * goods) — typically 8 * 4 = 32 property writes.
    /// Call this every tick.
    /// </summary>
    public void SyncInventories()
    {
        var gdLocations = (Godot.Collections.Array)_world.Call("get_economy_locations");
        var gdGoods = (Godot.Collections.Array)_world.Get("goods");
        for (int li = 0; li < gdLocations.Count; li++)
        {
            var gdLoc = (Resource)gdLocations[li];
            string locId = (string)gdLoc.Get("location_id");
            if (!_locationIdToIdx.TryGetValue(locId, out int csIdx)) continue;

            var csLoc = _locations[csIdx];
            var gdInv = (Resource)gdLoc.Get("inventory");
            gdInv.Call("_ensure_initialized");
            var gdStocks = (Godot.Collections.Dictionary)gdInv.Get("stocks");
            var gdPrices = (Godot.Collections.Dictionary)gdInv.Get("prices");

            for (int gi = 0; gi < _goods.Length; gi++)
            {
                var gdThing = (Resource)gdGoods[gi];
                gdStocks[gdThing] = csLoc.Stocks[gi];
                gdPrices[gdThing] = csLoc.Prices[gi];
            }
        }
    }

    /// <summary>
    /// Full sync: writes everything back including per-person data.
    /// This is O(total_population) — expensive for large worlds.
    /// Call this only when GDScript needs to read person-level data
    /// (e.g., UI display, metrics recording, save game).
    /// </summary>
    public void SyncBackToGdScript()
    {
        SyncInventories();

        var gdLocations = (Godot.Collections.Array)_world.Call("get_economy_locations");
        var gdGoods = (Godot.Collections.Array)_world.Get("goods");
        for (int li = 0; li < gdLocations.Count; li++)
        {
            var gdLoc = (Resource)gdLocations[li];
            string locId = (string)gdLoc.Get("location_id");
            if (!_locationIdToIdx.TryGetValue(locId, out int csIdx)) continue;

            var csLoc = _locations[csIdx];

            var gdPop = (GodotObject)gdLoc.Get("population");
            var gdPeople = (Godot.Collections.Array)gdPop.Get("people");
            var csPeople = csLoc.Population.People;

            // Build lookup from PersonId → GDScript person
            var gdById = new System.Collections.Generic.Dictionary<string, GodotObject>(gdPeople.Count);
            for (int pi = 0; pi < gdPeople.Count; pi++)
            {
                var gdPerson = (GodotObject)gdPeople[pi];
                string pid = (string)gdPerson.Get("person_id");
                gdById[pid] = gdPerson;
            }

            // Track which GDScript people still exist in C#
            var survivingIds = new HashSet<string>();

            for (int pi = 0; pi < csPeople.Count; pi++)
            {
                var csPerson = csPeople[pi];
                survivingIds.Add(csPerson.PersonId);

                if (gdById.TryGetValue(csPerson.PersonId, out var gdPerson))
                {
                    // Detect class/job changes for index update
                    var oldClass = (int)gdPerson.Get("social_class");
                    var oldJob = (int)gdPerson.Get("job");
                    bool classChanged = oldClass != (int)csPerson.SocialClass || oldJob != (int)csPerson.Job;

                    // Update existing person
                    gdPerson.Set("money", csPerson.Money);
                    gdPerson.Set("satisfaction", csPerson.Satisfaction);
                    gdPerson.Set("_fed_this_turn", csPerson.FedThisTurn);
                    gdPerson.Set("_comfort_this_turn", csPerson.ComfortThisTurn);
                    gdPerson.Set("social_class", (int)csPerson.SocialClass);
                    gdPerson.Set("job", (int)csPerson.Job);

                    if (classChanged)
                        gdPop.Call("notify_class_changed", gdPerson, oldClass, oldJob);

                    var gdPersonInv = (Godot.Collections.Dictionary)gdPerson.Get("inventory");
                    for (int gi = 0; gi < _goods.Length; gi++)
                    {
                        float amt = csPerson.GetInventory(gi);
                        if (amt > 0f)
                            gdPersonInv[(Resource)gdGoods[gi]] = amt;
                    }
                }
                else
                {
                    // Birth: create new GDScript person
                    var newGdPerson = CreateGdPerson(csPerson);
                    gdPop.Call("add_person", newGdPerson);
                }
            }

            // Deaths: remove GDScript people not in C#
            var toRemove = new List<GodotObject>();
            for (int pi = 0; pi < gdPeople.Count; pi++)
            {
                var gdPerson = (GodotObject)gdPeople[pi];
                string pid = (string)gdPerson.Get("person_id");
                if (!survivingIds.Contains(pid))
                    toRemove.Add(gdPerson);
            }
            foreach (var dead in toRemove)
                gdPop.Call("remove_person", dead);
        }
    }

    private GodotObject CreateGdPerson(CsPerson csPerson)
    {
        var script = GD.Load<Script>("res://src/economy/person.gd");
        var gdPerson = (GodotObject)script.Call("create",
            csPerson.PersonId,
            (int)csPerson.SocialClass,
            (int)csPerson.Job,
            csPerson.Money);
        // Override the auto-generated person_id with the C# one
        gdPerson.Set("person_id", csPerson.PersonId);
        gdPerson.Set("person_name", csPerson.PersonId);
        gdPerson.Set("satisfaction", csPerson.Satisfaction);
        gdPerson.Set("_fed_this_turn", csPerson.FedThisTurn);
        gdPerson.Set("_comfort_this_turn", csPerson.ComfortThisTurn);
        return gdPerson;
    }

    /// <summary>
    /// Get the total promotions count.
    /// </summary>
    public int GetTotalPromotions() => _engine?.TotalPromotions ?? 0;

    public int GetActiveContractsCount() => _engine?.ActiveContracts.Count ?? 0;
    public int GetCompletedContractsCount() => _engine?.CompletedContracts.Count ?? 0;
    public int GetTotalDeaths() => _engine?.TotalDeaths ?? 0;
    public int GetTotalBirths() => _engine?.TotalBirths ?? 0;

    /// <summary>
    /// Get imperial-bank info as a Dictionary. Reads from the imperial
    /// government's bank fields (folded from the deleted CsCentralBank).
    /// </summary>
    public Godot.Collections.Dictionary GetBankInfo()
    {
        var imperial = _engine?.ImperialGovernment;
        if (imperial == null) return new Godot.Collections.Dictionary();
        return new Godot.Collections.Dictionary
        {
            ["total_printed"] = imperial.TotalPrinted,
            ["reserves"] = imperial.Reserves,
            ["total_interest_collected"] = imperial.TotalInterestCollected,
            ["active_loans"] = imperial.ActiveLoans.Count,
            ["outstanding"] = imperial.GetTotalOutstanding(),
            ["imperial_location_id"] = imperial.LocationId,
        };
    }

    /// <summary>
    /// Geist info per location: desperation, bandit pool, last emission.
    /// GDScript bandit_spawner reads this for spawn pressure.
    /// </summary>
    public Godot.Collections.Dictionary GetGeistInfo(string locationId)
    {
        if (_engine == null) return new Godot.Collections.Dictionary();
        if (!_locationIdToIdx.TryGetValue(locationId, out int idx)) return new Godot.Collections.Dictionary();
        var geist = _engine.Locations[idx].Geist;
        if (geist == null) return new Godot.Collections.Dictionary();
        return new Godot.Collections.Dictionary
        {
            ["desperation"] = geist.Desperation,
            ["smoothed_desperation"] = geist.SmoothedDesperation,
            ["bandit_pool_size"] = geist.BanditPoolSize,
            ["bandit_affinity"] = geist.BanditAffinity,
            ["cultural_cohesion"] = geist.CulturalCohesion,
            ["last_bandit_slots_emitted"] = geist.LastBanditSlotsEmitted,
            ["last_spawn_recommendation"] = geist.LastSpawnRecommendation,
        };
    }

    /// <summary>
    /// Bandit pressure (0..1) for the given location, derived from Geist desperation.
    /// Replaces GDScript BanditSpawner.calculate_pressure for the pre-spawn check.
    /// </summary>
    public float GetBanditPressure(string locationId)
    {
        if (_engine == null) return 0f;
        if (!_locationIdToIdx.TryGetValue(locationId, out int idx)) return 0f;
        var geist = _engine.Locations[idx].Geist;
        return geist?.Desperation ?? 0f;
    }

    /// <summary>
    /// Mercenary-work demand scalar for the given location, derived from
    /// the government's last GenerateOrders pass.
    /// </summary>
    public float GetMercenaryDemand(string locationId)
    {
        return 0f;
    }

    public Godot.Collections.Array GetGovernmentInfo()
    {
        var result = new Godot.Collections.Array();
        if (_engine == null) return result;
        for (int li = 0; li < _engine.Locations.Length; li++)
        {
            var loc = _engine.Locations[li];
            if (loc.Government == null) continue;
            var gov = loc.Government;
            result.Add(new Godot.Collections.Dictionary
            {
                ["location_id"] = loc.LocationId,
                ["treasury"] = gov.Treasury,
                ["tax_collected"] = gov.TaxCollectedLastTick,
                ["active_directives"] = gov.ActiveDirectives.Count,
                ["workers_hired"] = gov.WorkersHiredLastTick,
                ["wages_paid"] = gov.WagesPaidLastTick,
            });
        }
        return result;
    }

    public Godot.Collections.Dictionary GetGuildInfo()
    {
        var result = new Godot.Collections.Dictionary();
        if (_engine == null) return result;
        for (int li = 0; li < _engine.Locations.Length; li++)
        {
            var loc = _engine.Locations[li];
            var guildArray = new Godot.Collections.Array();
            for (int ai = 0; ai < loc.Actors.Count; ai++)
            {
                if (loc.Actors[ai] is CsGuild guild)
                {
                    guildArray.Add(new Godot.Collections.Dictionary
                    {
                        ["guild_name"] = guild.GuildName,
                        ["treasury"] = guild.Treasury,
                        ["worker_count"] = guild.WorkerCount,
                        ["produced_last_tick"] = guild.ProducedLastTick,
                        ["recruited_last_tick"] = guild.RecruitedLastTick,
                        ["wages_paid_last_tick"] = guild.WagesPaidLastTick,
                        ["specialization_indices"] = BuildSpecIndices(guild.Specializations),
                    });
                }
            }
            if (guildArray.Count > 0)
                result[loc.LocationId] = guildArray;
        }
        return result;
    }

    private CsPerson MirrorPerson(GodotObject gdPerson)
    {
        int goodsCount = _goods.Length;
        var csPerson = new CsPerson(goodsCount)
        {
            PersonId = (string)gdPerson.Get("person_id"),
            PersonName = (string)gdPerson.Get("person_name"),
            SocialClass = (SocialClass)(int)gdPerson.Get("social_class"),
            Job = (JobType)(int)gdPerson.Get("job"),
            Money = (float)gdPerson.Get("money"),
            Satisfaction = (float)gdPerson.Get("satisfaction"),
            IncomePerTurn = (float)gdPerson.Get("income_per_turn"),
            EmployerId = (string)gdPerson.Get("employer_id"),
        };

        // (Brain field removed: per-class decision logic now lives on CsPerson directly.)

        // Mirror inventory
        var gdInv = (Godot.Collections.Dictionary)gdPerson.Get("inventory");
        foreach (var kv in gdInv)
        {
            var thing = (Resource)kv.Key;
            string thingId = (string)thing.Get("thing_id");
            if (_thingIdToIdx.TryGetValue(thingId, out int idx))
                csPerson.SetInventory(idx, (float)kv.Value);
        }

        return csPerson;
    }

    private Godot.Collections.Dictionary ConvertResult(CsEconomyTickResult csResult)
    {
        var result = new Godot.Collections.Dictionary
        {
            ["turn"] = csResult.Turn,
            ["deaths"] = csResult.Deaths,
            ["births"] = csResult.Births,
        };

        // Location snapshots
        var snapshots = new Godot.Collections.Array();
        foreach (var snap in csResult.LocationSnapshots)
        {
            var snapDict = new Godot.Collections.Dictionary
            {
                ["location_id"] = snap.LocationId,
                ["location_name"] = snap.LocationName,
                ["population_count"] = snap.PopulationCount,
                ["avg_satisfaction"] = snap.AvgSatisfaction,
                ["avg_money"] = snap.AvgMoney,
                ["peasant_count"] = snap.PeasantCount,
                ["bourgeois_count"] = snap.BourgeoisCount,
                ["noble_count"] = snap.NobleCount,
                ["government_treasury"] = snap.GovernmentTreasury,
                ["government_tax_collected"] = snap.GovernmentTaxCollected,
                ["government_directives_count"] = snap.GovernmentDirectivesCount,
                ["government_workers_hired"] = snap.GovernmentWorkersHired,
                ["guild_treasury"] = snap.GuildTreasury,
                ["guild_produced"] = snap.GuildProduced,
                ["guild_worker_count"] = snap.GuildWorkerCount,
                ["geist_desperation"] = snap.GeistDesperation,
                ["geist_bandit_pool"] = snap.GeistBanditPool,
                ["geist_bandit_slots_emitted"] = snap.GeistBanditSlotsEmitted,
            };
            var stocksDict = new Godot.Collections.Dictionary();
            var pricesDict = new Godot.Collections.Dictionary();
            for (int gi = 0; gi < _goods.Length; gi++)
            {
                stocksDict[_goods[gi].ThingId] = snap.Stocks[gi];
                pricesDict[_goods[gi].ThingId] = snap.Prices[gi];
            }
            snapDict["stocks"] = stocksDict;
            snapDict["prices"] = pricesDict;
            snapshots.Add(snapDict);
        }
        result["location_snapshots"] = snapshots;

        // Moves created
        var movesCreated = new Godot.Collections.Array();
        foreach (var move in csResult.MovesCreated)
        {
            movesCreated.Add(ConvertMove(move));
        }
        result["moves_created"] = movesCreated;

        // Moves completed
        var movesCompleted = new Godot.Collections.Array();
        foreach (var move in csResult.MovesCompleted)
        {
            movesCompleted.Add(ConvertMove(move));
        }
        result["moves_completed"] = movesCompleted;

        // Shipment dispatches — these are what the strategy layer uses
        // to spawn caravans
        var dispatches = new Godot.Collections.Array();
        foreach (var dispatch in csResult.ShipmentDispatches)
        {
            var d = new Godot.Collections.Dictionary
            {
                ["shipment_id"] = dispatch.ShipmentId,
                ["guard_count"] = dispatch.GuardCount,
                ["move"] = ConvertMove(dispatch.Move),
            };
            dispatches.Add(d);
        }
        result["shipment_dispatches"] = dispatches;

        return result;
    }

    private static bool CoveredByGuild(CsGuild guild, int thingIdx)
    {
        foreach (var spec in guild.Specializations)
            if (spec.ThingIdx == thingIdx) return true;
        return false;
    }

    private static Godot.Collections.Array BuildSpecIndices(CsGuildSpecialization[] specs)
    {
        var arr = new Godot.Collections.Array();
        foreach (var spec in specs) arr.Add(spec.ThingIdx);
        return arr;
    }

    private Godot.Collections.Dictionary ConvertMove(CsEconomyMove move)
    {
        return new Godot.Collections.Dictionary
        {
            ["thing_id"] = move.ThingId,
            ["quantity"] = move.Quantity,
            ["source_location_id"] = move.SourceLocationId,
            ["dest_location_id"] = move.DestLocationId,
            ["turns_remaining"] = move.TurnsRemaining,
            ["state"] = (int)move.State,
            ["origin"] = move.Origin,
        };
    }
}
