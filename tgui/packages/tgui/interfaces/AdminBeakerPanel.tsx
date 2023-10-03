import { useBackend, useLocalState } from '../backend';
import { Box, Dropdown, Section, Stack } from '../components';
import { DropdownEntry } from '../components/Dropdown';
import { Window } from '../layouts';

type Reagent = {
  path: string;
  name: string;
};

type ReagentContainer = {
  path: string;
  name: string;
  volume: number;
};

type PanelData = {
  reagent_types: Reagent[];
  reagent_container_types: ReagentContainer[];
};

type SpawnMode = 'Container' | 'Grenade';

export const AdminBeakerPanel = (props, context) => {
  const { data, act } = useBackend<PanelData>(context);
  const { reagent_types, reagent_container_types } = data;

  const [spawnMode, setSpawnMode] = useLocalState<SpawnMode>(
    context,
    'spawnMode',
    'Container'
  );

  const makingGrenade = spawnMode === 'Grenade';

  const reagentChoices = reagent_types.map<DropdownEntry>((reagent) => ({
    value: reagent.path,
    displayText: reagent.name,
  }));
  const containerChoices = reagent_container_types.map<DropdownEntry>(
    (reagent) => ({ value: reagent.path, displayText: reagent.name })
  );

  return (
    <Window
      width={550 * (makingGrenade ? 2 : 1)}
      height={720}
      theme="admin"
      title="Create Reagent Containers">
      <Window.Content>
        <Section title="Create Reagents" fill>
          <Stack vertical fill>
            <Stack.Item grow={1}>
              <Box>
                <Dropdown
                  selected={spawnMode}
                  options={['Container', 'Grenade']}
                  onSelected={(selected: SpawnMode) => setSpawnMode(selected)}
                />
              </Box>
            </Stack.Item>
            <Stack.Item grow={5}>
              <Stack fill>
                <Stack.Item grow={1}>
                  <Section
                    title={`Container${makingGrenade ? ' 1' : ''}`}
                    fill
                    buttons={<Dropdown options={containerChoices} />}
                  />
                </Stack.Item>

                {makingGrenade && (
                  <>
                    <Stack.Divider />
                    <Stack.Item grow={1}>
                      <Stack vertical fill>
                        <Section title="Container 2" fill />
                      </Stack>
                    </Stack.Item>
                  </>
                )}
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
