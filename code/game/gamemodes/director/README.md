# Director Gamemode

(should be in sync with [the hackmd](https://hackmd.io/wQ-MVkNkS8yDsChdquGq0Q))

## Goals of Director:
- Kill events subsystem and merge it into the gamemode controller itself
- Provide workload across all departments and antagonists equally
- Rework threat into a "max heat" system, at which point no more rulesets roll, 
ensuring that rounds could theoretically go on without losing antagonism.

## Glossary

### Director Target
A certain (sub)department which is targetted and monitored by Director.

### Target (Max) Chaos
How many objectives a target can have at once.

### Director Influence
A component that lets a datum influence the director by adding chaos to a target.

### Picking Rulesets and Events

Dynamic injects chaos into the round by picking rulesets (antagonists only) based on a token system. 
The amount of tokens is set at the beginning of a round and gets reduced upon picking rulesets.

Instead of a token based system, Director chooses rulesets to fulfill a "chaos" quota, or a maximum amount of chaos. This can be caused not only by players antagonizing the station (e.g. blowing up a bomb), but also through natural events such as meteor showers or diseases.

Not all parts of the station are affected equally by an event, either. A crazed gunman in departures would not affect Engineering, for example. Director tries to spread this chaos evenly across all departments with the help of antagonist rulesets and events.


