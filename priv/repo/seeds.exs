alias XMatrix.Repo
alias XMatrix.Strategies.{Strategy, StrategyCorrelation, StrategyElement}

Repo.delete_all(StrategyCorrelation)
Repo.delete_all(StrategyElement)
Repo.delete_all(Strategy)

strategy =
  %Strategy{}
  |> Strategy.changeset(%{
    title: "Multi-agency homelessness reduction strategy",
    description:
      "A shared X-Matrix for council, health, housing, and nonprofit partners working to reduce homelessness through prevention, rapid rehousing, and coordinated support."
  })
  |> Repo.insert!()

elements = [
  %{
    element_type: :true_north,
    title: "Everyone has a safe, stable place to call home",
    description: "Make homelessness rare, brief, and non-recurring across the city.",
    position: 1
  },
  %{
    element_type: :aspiration,
    title: "Reduce rough sleeping by 50%",
    description: "Halve the monthly rough-sleeper count within two years.",
    position: 10
  },
  %{
    element_type: :aspiration,
    title: "Prevent avoidable family homelessness",
    description: "Reduce homelessness presentations from families at risk of eviction.",
    position: 20
  },
  %{
    element_type: :strategy,
    title: "Intervene before crisis",
    description:
      "Find households at risk earlier and resolve housing instability before eviction or discharge.",
    position: 30
  },
  %{
    element_type: :strategy,
    title: "Coordinate around the person",
    description: "Use one shared plan across outreach, health, housing, and benefits teams.",
    position: 40
  },
  %{
    element_type: :evidence,
    title: "Median days from referral to stable housing",
    description:
      "Leading indicator for whether the pathway is becoming faster and easier to navigate.",
    position: 50
  },
  %{
    element_type: :evidence,
    title: "Evictions prevented after early warning",
    description: "Monthly count of households kept safely housed after partner referral.",
    position: 60
  },
  %{
    element_type: :tactic,
    title: "Shared by-name case conference",
    description: "Weekly multi-agency review of people sleeping rough or at imminent risk.",
    position: 70
  },
  %{
    element_type: :tactic,
    title: "Hospital and prison discharge housing protocol",
    description: "Discharge planning starts early and includes a named housing lead.",
    position: 80
  },
  %{
    element_type: :tactic,
    title: "Flexible prevention fund",
    description:
      "Small, rapid payments for arrears, deposits, furnishings, or transport when they prevent homelessness.",
    position: 90
  }
]

elements_by_title =
  elements
  |> Enum.map(fn attrs ->
    element =
      %StrategyElement{}
      |> StrategyElement.changeset(Map.put(attrs, :strategy_id, strategy.id))
      |> Repo.insert!()

    {element.title, element}
  end)
  |> Map.new()

correlations = [
  {"Intervene before crisis", "Prevent avoidable family homelessness", :strong,
   "Prevention work directly supports the family homelessness aspiration."},
  {"Coordinate around the person", "Reduce rough sleeping by 50%", :medium,
   "Coordination improves speed and continuity for people sleeping rough."},
  {"Median days from referral to stable housing", "Reduce rough sleeping by 50%", :strong,
   "Shorter pathways should reduce the time people spend without housing."},
  {"Evictions prevented after early warning", "Prevent avoidable family homelessness", :medium,
   "More prevented evictions should reduce avoidable presentations."},
  {"Shared by-name case conference", "Coordinate around the person", :strong,
   "A shared list and forum makes coordinated work practical."},
  {"Hospital and prison discharge housing protocol", "Intervene before crisis", :medium,
   "Earlier discharge planning closes a common route into homelessness."},
  {"Flexible prevention fund", "Evictions prevented after early warning", :strong,
   "Fast discretionary help should show up first as prevented evictions."},
  {"Shared by-name case conference", "Median days from referral to stable housing", :weak,
   "The conference can reveal blockers, but does not itself create housing supply."}
]

Enum.each(correlations, fn {source_title, target_title, strength, rationale} ->
  source = Map.fetch!(elements_by_title, source_title)
  target = Map.fetch!(elements_by_title, target_title)

  %StrategyCorrelation{}
  |> StrategyCorrelation.changeset(%{
    strategy_id: strategy.id,
    source_element_id: source.id,
    target_element_id: target.id,
    strength: strength,
    rationale: rationale
  })
  |> Repo.insert!()
end)
