import { Component, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Dimmer,
  Modal,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  TextArea,
  Tabs,
} from 'tgui-core/components';
import { fetchRetry } from 'tgui-core/http';
import type { BooleanLike } from 'tgui-core/react';

import { resolveAsset } from '../../assets';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { GenericUplink, type Item } from './GenericUplink';
import { PrimaryObjectiveMenu } from './PrimaryObjectiveMenu';

type UplinkItem = {
  id: string;
  name: string;
  icon: string;
  icon_state: string;
  cost: number;
  minimum_traitor_reputation?: number;
  desc: string;
  category: string;
  purchasable_from: number;
  restricted: BooleanLike;
  limited_stock: number;
  stock_key: string;
  restricted_roles: string;
  restricted_species: string;
  population_minimum: number;
  cost_override_string: string;
  lock_other_purchases: BooleanLike;
  ref?: string;
};

type UplinkData = {
  telecrystals: number;
  joined_population?: number;
  lockable: BooleanLike;
  uplink_flag: number;
  assigned_role: string;
  assigned_species: string;
  debug: BooleanLike;
  extra_purchasable: UplinkItem[];
  extra_purchasable_stock: {
    [key: string]: number;
  };
  current_stock: {
    [key: string]: number;
  };
  primary_objectives: {
    [key: number]: string;
  };
  purchased_items: number;
  shop_locked: BooleanLike;
  can_renegotiate: BooleanLike;
  traitor_reputation?: TraitorReputationData;
};

type TraitorReputationData = {
  name: string;
  reputation: number;
  passive_reputation_gain: number;
  threat_level: string;
  tier: {
    threshold: number;
    bonus_tc: number;
    unlocks: string[];
    threat_level: string;
  };
  tiers: {
    threshold: number;
    bonus_tc: number;
    unlocks: string[];
    threat_level: string;
  }[];
  stats: {
    completed_goals: number;
    successful_infiltrations: number;
    spent_tc: number;
    earned_tc: number;
  };
  services: {
    contracts: {
      contract_id: string;
      type: string;
      description: string;
      location: string;
      target: string;
      can_turn_in: BooleanLike;
      item_tier: string;
      tc_drop_chance: number;
      reward_tc: number;
      reputation_reward: number;
    }[];
    events: {
      id: string;
      name: string;
      description: string;
      location: string;
      reward_tc: number;
      reward_reputation: number;
      tc_drop_chance: number;
    }[];
    agent_chat_messages: {
      sender: string;
      message: string;
      timestamp: string;
      outgoing: BooleanLike;
    }[];
    market_items: string[];
  };
};

type UplinkState = {
  allItems: UplinkItem[];
  allCategories: string[];
  currentTab: number;
};

type ServerData = {
  items: UplinkItem[];
  categories: string[];
};

type ItemExtraData = Item & {
  extraData: {
    ref?: string;
    icon: string;
    icon_state: string;
  };
};

const threatLevelLabels: Record<string, string> = {
  caution: 'Осторожность',
  warning: 'Предупреждение',
  high_alert: 'Высокая тревога',
  critical: 'Критический',
  neutral: 'Нейтральный',
};

const contractTypeLabels: Record<string, string> = {
  assassination: 'Устранение цели',
  delivery: 'Доставка',
  execution: 'Ликвидация',
  intel: 'Сбор разведданных',
  item_retrieval: 'Добыча предмета',
  retrieval: 'Извлечение',
  sabotage: 'Саботаж',
};

const contractLocationLabels: Record<string, string> = {
  cargo: 'Карго',
  command: 'Командование',
  engineering: 'Инженерный отдел',
  medical: 'Медицинский отдел',
  mining: 'Шахтёрский отдел',
  random: 'Случайный сектор',
  science: 'Научный отдел',
  security: 'Служба безопасности',
  station: 'Станция',
};

const eventNameLabels: Record<string, string> = {
  very_important_cargo: 'Перехваченный груз',
  kill_but_not_finished: 'Контракт на устранение',
  hitman_contract: 'Контракт киллера',
  silent_breach: 'Тихое проникновение',
};

const perkDetails: Record<string, { name: string; description: string }> = {
  agent_chat: {
    name: 'Канал связи агентов',
    description: 'Открывает доступ к закрытому каналу связи Синдиката.',
  },
  first_items: {
    name: 'Снаряжение агента',
    description: 'Открывает доступ к дополнительным предложениям аплинка.',
  },
  telecom_sabotage: {
    name: 'Саботаж телекоммуникаций',
    description:
      'Открывает возможность саботировать телекоммуникационную сеть.',
  },
  threat_rise: {
    name: 'Рост уровня угрозы',
    description: 'Действия агента начинают привлекать больше внимания.',
  },
  crew_conversion: {
    name: 'Вербовка экипажа',
    description: 'Открывает возможность переманивать членов экипажа.',
  },
  bureaucratic_interest: {
    name: 'Бюрократический интерес',
    description: 'Действия агента вызывают дополнительную проверку документов.',
  },
  kill_marker: {
    name: 'Маркер цели',
    description: 'Позволяет отмечать приоритетные цели.',
  },
  evac_override: {
    name: 'Влияние на эвакуацию',
    description: 'Открывает возможность вмешиваться в процедуры эвакуации.',
  },
  department_leak: {
    name: 'Утечка данных отдела',
    description: 'Открывает доступ к конфиденциальным сведениям отделов.',
  },
};

const ReputationPanel = (props: { reputation: TraitorReputationData }) => {
  const { reputation } = props;
  const { act } = useBackend<UplinkData>();
  const { services, stats, tiers } = reputation;
  const [showStatistics, setShowStatistics] = useState(false);
  const [showAgentChat, setShowAgentChat] = useState(false);
  const [chatMessage, setChatMessage] = useState('');
  const nextTier = tiers.find((tier) => tier.threshold > reputation.reputation);
  const previousTierThreshold = tiers.reduce(
    (threshold, tier) =>
      tier.threshold <= reputation.reputation ? tier.threshold : threshold,
    0,
  );
  const progress = nextTier
    ? (reputation.reputation - previousTierThreshold) /
      (nextTier.threshold - previousTierThreshold)
    : 1;
  const sendAgentMessage = () => {
    if (!chatMessage.trim()) {
      return;
    }
    act('traitor_reputation_action', {
      perk: 'agent_chat',
      message: chatMessage,
    });
    setChatMessage('');
  };

  return (
    <Section
      fill
      scrollable
      title={`Досье агента: ${reputation.name}`}
      buttons={
        reputation.reputation >= 150 && (
          <Button
            icon={showAgentChat ? 'address-card' : 'comments'}
            onClick={() => setShowAgentChat(!showAgentChat)}
          >
            {showAgentChat ? 'Досье агента' : 'Канал агентов'}
          </Button>
        )
      }
    >
      {showStatistics && (
        <Modal width="500px" align="center">
          <Section
            title="Статистика агента"
            buttons={
              <Button
                icon="times"
                color="bad"
                onClick={() => setShowStatistics(false)}
              />
            }
          >
            <Stack vertical>
              <Stack.Item>Цели выполнены: {stats.completed_goals}</Stack.Item>
              <Stack.Item>
                Успешные внедрения: {stats.successful_infiltrations}
              </Stack.Item>
              <Stack.Item>Заработано: {stats.earned_tc} TC</Stack.Item>
              <Stack.Item>Потрачено: {stats.spent_tc} TC</Stack.Item>
            </Stack>
          </Section>
        </Modal>
      )}
      {showAgentChat && (
        <Modal width="650px" align="center">
          <Section
            title="Канал агентов"
            buttons={
              <Button
                icon="times"
                color="bad"
                onClick={() => setShowAgentChat(false)}
              />
            }
          >
            <Stack vertical fill>
              <Stack.Item grow>
                <Section fill scrollable>
                  <Stack vertical>
                    {services.agent_chat_messages.length ? (
                      services.agent_chat_messages.map((message, index) => (
                        <Stack.Item key={`${message.timestamp}-${index}`}>
                          <Section
                            title={`${message.sender} · ${message.timestamp}`}
                            textAlign={message.outgoing ? 'right' : 'left'}
                          >
                            {message.message}
                          </Section>
                        </Stack.Item>
                      ))
                    ) : (
                      <Box color="label">Сообщений пока нет.</Box>
                    )}
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Stack align="center">
                  <Stack.Item grow>
                    <TextArea
                      value={chatMessage}
                      placeholder="Сообщение агентам..."
                      maxLength={200}
                      onChange={setChatMessage}
                      onEnter={sendAgentMessage}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="arrow-right"
                      disabled={!chatMessage.trim()}
                      onClick={sendAgentMessage}
                    >
                      Отправить
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Section>
        </Modal>
      )}
      <Stack vertical>
        <Stack.Item>
          <Section
            title="Репутация и уровень угрозы"
            buttons={
              <Button icon="list-ol" onClick={() => setShowStatistics(true)}>
                Статистика
              </Button>
            }
          >
            <Stack vertical>
              <Stack.Item>
                <Box inline bold fontSize="16px">
                  {reputation.reputation} REP
                </Box>
                <Box inline ml={1} color="label">
                  · пассивно +{reputation.passive_reputation_gain} REP/мин
                </Box>
              </Stack.Item>
              <Stack.Item>
                Уровень угрозы:{' '}
                <Box inline bold>
                  {threatLevelLabels[reputation.threat_level] ||
                    reputation.threat_level}
                </Box>
              </Stack.Item>
              <Stack.Item>
                <ProgressBar value={progress} color="bad">
                  {nextTier
                    ? `${reputation.reputation} / ${nextTier.threshold} REP · ${nextTier.bonus_tc} TC`
                    : `${reputation.reputation} REP · максимальный уровень`}
                </ProgressBar>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
        <Stack.Item>
          <Section title="Перки и уровни допуска">
            <Stack vertical>
              {tiers.map((tier) => {
                const unlocked = reputation.reputation >= tier.threshold;
                return (
                  <Stack.Item key={tier.threshold}>
                    <Collapsible
                      title={`${unlocked ? 'ДОСТУПЕН' : 'ЗАКРЫТ'} · ${tier.threshold} REP · +${tier.bonus_tc} TC`}
                    >
                      <Stack vertical>
                        <Stack.Item>
                          Уровень угрозы:{' '}
                          {threatLevelLabels[tier.threat_level] ||
                            tier.threat_level}
                        </Stack.Item>
                        {tier.unlocks.map((perk) => {
                          const details = perkDetails[perk];
                          return (
                            <Stack.Item key={perk}>
                              <Box bold>{details?.name || perk}</Box>
                              <Box color="label">
                                {details?.description ||
                                  'Награда уровня репутации.'}
                              </Box>
                            </Stack.Item>
                          );
                        })}
                      </Stack>
                    </Collapsible>
                  </Stack.Item>
                );
              })}
            </Stack>
          </Section>
        </Stack.Item>
        <Stack.Item>
          <Section title="Контракты">
            {services.contracts.length ? (
              services.contracts.map((contract) => (
                <Section
                  key={contract.contract_id}
                  title={`${contractTypeLabels[contract.type] || contract.type} · ${contractLocationLabels[contract.location] || contract.location}`}
                >
                  {contract.item_tier && (
                    <Box bold>
                      Сложность:{' '}
                      {contract.item_tier === 'easy'
                        ? 'низкая'
                        : contract.item_tier === 'medium'
                          ? 'средняя'
                          : 'высокая'}
                    </Box>
                  )}
                  <Box>{contract.description}</Box>
                  <Box>
                    {contract.item_tier
                      ? `Награда: ${contract.reputation_reward} REP; ${contract.reward_tc} TC с шансом ${contract.tc_drop_chance}%`
                      : `Награда: ${contract.reward_tc} TC и ${contract.reputation_reward} репутации`}
                  </Box>
                  {contract.can_turn_in && (
                    <Button
                      onClick={() =>
                        act('traitor_reputation_action', {
                          perk: 'complete_item_contract',
                          contract_id: contract.contract_id,
                        })
                      }
                    >
                      Сдать предмет
                    </Button>
                  )}
                </Section>
              ))
            ) : (
              <Box color="label">Активных контрактов нет.</Box>
            )}
          </Section>
        </Stack.Item>
        <Stack.Item>
          <Section title="События">
            {services.events.length ? (
              services.events.map((event) => (
                <Section
                  key={event.id}
                  title={`${eventNameLabels[event.name] || event.name} · ${event.location}`}
                >
                  <Box>{event.description}</Box>
                  {event.name === 'very_important_cargo' ? (
                    <Box>Награда: 20 REP и 5 TC за получение кристалла</Box>
                  ) : event.name === 'kill_but_not_finished' ? (
                    <Box>
                      Награда: {event.reward_reputation} REP и {event.reward_tc}{' '}
                      TC с шансом {event.tc_drop_chance}%
                    </Box>
                  ) : (
                    <Box>
                      Награда: {event.reward_tc} TC и {event.reward_reputation}{' '}
                      репутации
                    </Box>
                  )}
                </Section>
              ))
            ) : (
              <Box color="label">Активных событий нет.</Box>
            )}
          </Section>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

// Cache response so it's only sent once
let fetchServerData: Promise<ServerData> | undefined;

export class Uplink extends Component<any, UplinkState> {
  constructor(props) {
    super(props);
    this.state = {
      allItems: [],
      allCategories: [],
      currentTab: 0,
    };
  }

  componentDidMount() {
    this.populateServerData();
  }

  async populateServerData() {
    if (!fetchServerData) {
      fetchServerData = fetchRetry(resolveAsset('uplink.json')).then(
        (response) => response.json(),
      );
    }
    const { data } = useBackend<UplinkData>();

    const uplinkFlag = data.uplink_flag;
    const uplinkRole = data.assigned_role;
    const uplinkSpecies = data.assigned_species;

    const uplinkData = await fetchServerData;

    const availableCategories: string[] = [];
    uplinkData.items = uplinkData.items.filter((value) => {
      if (
        value.restricted_roles.length > 0 &&
        !value.restricted_roles.includes(uplinkRole) &&
        !data.debug
      ) {
        return false;
      }
      if (
        value.restricted_species.length > 0 &&
        !value.restricted_species.includes(uplinkSpecies) &&
        !data.debug
      ) {
        return false;
      }
      if (value.purchasable_from & uplinkFlag) {
        return true;
      }
      return false;
    });

    uplinkData.items.forEach((item) => {
      if (!availableCategories.includes(item.category)) {
        availableCategories.push(item.category);
      }
    });

    uplinkData.categories = uplinkData.categories.filter((value) =>
      availableCategories.includes(value),
    );

    this.setState({
      allItems: uplinkData.items,
      allCategories: uplinkData.categories,
    });
  }

  render() {
    const { data, act } = useBackend<UplinkData>();
    const {
      telecrystals,
      joined_population,
      primary_objectives,
      can_renegotiate,
      traitor_reputation,
      extra_purchasable,
      extra_purchasable_stock,
      current_stock,
      lockable,
      purchased_items,
      shop_locked,
    } = data;
    const { allItems, allCategories, currentTab } = this.state as UplinkState;
    const itemsToAdd = [...allItems];
    const items: ItemExtraData[] = [];
    itemsToAdd.push(...extra_purchasable);
    for (let i = 0; i < extra_purchasable.length; i++) {
      const item = extra_purchasable[i];
      if (!allCategories.includes(item.category)) {
        allCategories.push(item.category);
      }
    }
    for (let i = 0; i < itemsToAdd.length; i++) {
      const item = itemsToAdd[i];
      const hasEnoughPop =
        !joined_population || joined_population >= item.population_minimum;
      const minimumReputation = item.minimum_traitor_reputation || 0;
      const reputationLocked =
        !!traitor_reputation &&
        traitor_reputation.reputation < minimumReputation;

      let stock: number | null = current_stock[item.stock_key];
      if (item.ref) {
        stock = extra_purchasable_stock[item.ref];
      }
      if (!stock && stock !== 0) {
        stock = null;
      }
      const canBuy = telecrystals >= item.cost && (stock === null || stock > 0);
      items.push({
        id: item.id,
        name: item.name,
        icon: item.icon,
        icon_state: item.icon_state,
        category: item.category,
        locked: reputationLocked,
        lock_tooltip: `Требуется ${minimumReputation} REP`,
        desc: (
          <>
            <Box>{item.desc}</Box>
            {reputationLocked && (
              <NoticeBox mt={1}>
                Для покупки требуется {minimumReputation} REP.
              </NoticeBox>
            )}
            {(item.lock_other_purchases && (
              <NoticeBox mt={1}>
                Покупка этого предмета навсегда заблокирует возможность
                дальнейших покупок. К тому же, если вы купили любой другой
                предмет, то вы не сможете купить этот.
              </NoticeBox>
            )) ||
              null}
          </>
        ),
        cost: <Box>{item.cost_override_string || `${item.cost} TC`}</Box>,
        population_tooltip:
          'This item is not cleared for operations performed against stations crewed by fewer than ' +
          item.population_minimum +
          ' people.',
        insufficient_population: !hasEnoughPop,
        disabled:
          !canBuy ||
          !hasEnoughPop ||
          reputationLocked ||
          (item.lock_other_purchases && purchased_items > 0),
        extraData: {
          ref: item.ref,
          icon: item.icon,
          icon_state: item.icon_state,
        },
      });
    }

    return (
      <Window width={700} height={600} theme="syndicate">
        <Window.Content>
          <Stack fill vertical>
            <Stack.Item>
              <Section fitted>
                <Stack fill>
                  {!!(primary_objectives || traitor_reputation) && (
                    <Stack.Item grow={1}>
                      <Tabs fluid>
                        {primary_objectives && (
                          <Tabs.Tab
                            style={{
                              overflow: 'hidden',
                              whiteSpace: 'nowrap',
                              textOverflow: 'ellipsis',
                            }}
                            icon="star"
                            selected={currentTab === 0}
                            onClick={() => this.setState({ currentTab: 0 })}
                          >
                            Основные задачи
                          </Tabs.Tab>
                        )}
                        {!!traitor_reputation && (
                          <Tabs.Tab
                            style={{
                              overflow: 'hidden',
                              whiteSpace: 'nowrap',
                              textOverflow: 'ellipsis',
                            }}
                            icon="chart-line"
                            selected={currentTab === 1}
                            onClick={() => this.setState({ currentTab: 1 })}
                          >
                            Репутация
                          </Tabs.Tab>
                        )}
                        <Tabs.Tab
                          style={{
                            overflow: 'hidden',
                            whiteSpace: 'nowrap',
                            textOverflow: 'ellipsis',
                          }}
                          icon="store"
                          selected={currentTab === 2}
                          onClick={() => this.setState({ currentTab: 2 })}
                        >
                          Рынок
                        </Tabs.Tab>
                      </Tabs>
                    </Stack.Item>
                  )}

                  {!!lockable && (
                    <Stack.Item>
                      <Button
                        lineHeight={2.5}
                        textAlign="center"
                        icon="lock"
                        color="transparent"
                        px={2}
                        onClick={() => act('lock')}
                      >
                        Закрыть
                      </Button>
                    </Stack.Item>
                  )}
                </Stack>
              </Section>
            </Stack.Item>
            <Stack.Item grow>
              {(currentTab === 0 && primary_objectives && (
                <PrimaryObjectiveMenu
                  primary_objectives={primary_objectives}
                  can_renegotiate={can_renegotiate}
                />
              )) ||
                (currentTab === 1 && traitor_reputation && (
                  <ReputationPanel reputation={traitor_reputation} />
                )) || (
                  <>
                    <GenericUplink
                      currency={`${telecrystals} TC`}
                      categories={allCategories}
                      items={items}
                      handleBuy={(item: ItemExtraData) => {
                        if (!item.extraData?.ref) {
                          act('buy', { path: item.id });
                        } else {
                          act('buy', { ref: item.extraData.ref });
                        }
                      }}
                    />
                    {(shop_locked && !data.debug && (
                      <Dimmer>
                        <Box
                          color="red"
                          fontFamily={'Bahnschrift'}
                          fontSize={3}
                          align={'top'}
                          as="span"
                        >
                          РЫНОК ЗАБЛОКИРОВАН
                        </Box>
                      </Dimmer>
                    )) ||
                      null}
                  </>
                )}
            </Stack.Item>
          </Stack>
        </Window.Content>
      </Window>
    );
  }
}
