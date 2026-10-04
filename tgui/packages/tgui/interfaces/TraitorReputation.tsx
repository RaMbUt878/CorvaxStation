import { useState } from 'react';
import { Box, Button, ByondUi, Flex, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts/Window';

interface ContractItem {
  contract_type: string;
  location: string;
  reward_tc: number;
  reputation_reward: number;
}

interface TraitorReputationData {
  name: string;
  player_name?: string;
  reputation: number;
  total_tc: number;
  earned_tc?: number;
  spent_tc?: number;
  completed_goals?: number;
  successful_infiltrations?: number;
  threat_level?: string;
  agent_preview_id?: string;
  tabs?: string[];
  stats?: {
    completed_goals?: number;
    successful_infiltrations?: number;
    spent_tc?: number;
    earned_tc?: number;
  };
  services?: {
    contracts: ContractItem[];
    events: Array<{ event_name: string; location: string; reward_tc: number }>;
    market_items: string[];
  };
}

const tabLabels: Record<string, string> = {
  services: 'Услуги',
  reinforcement: 'Подкрепление',
  black_market: 'Чёрный рынок',
};

const threatLabels: Record<string, string> = {
  neutral: 'нейтральный',
  caution: 'осторожно',
  warning: 'предупреждение',
  high_alert: 'высокая тревога',
  critical: 'критический',
};

export const TraitorReputation = () => {
  const { data } = useBackend<TraitorReputationData>();
  const [tab, setTab] = useState<string>('services');

  const safeData = data ?? {
    name: 'Агент',
    reputation: 0,
    total_tc: 0,
    threat_level: 'neutral',
    tabs: ['services', 'reinforcement', 'black_market'],
    services: {
      contracts: [],
      events: [],
      market_items: [],
    },
  };

  const tabs = safeData.tabs ?? ['services', 'reinforcement', 'black_market'];
  const stats = safeData.stats ?? {
    completed_goals: safeData.completed_goals ?? 0,
    successful_infiltrations: safeData.successful_infiltrations ?? 0,
    spent_tc: safeData.spent_tc ?? 0,
    earned_tc: safeData.earned_tc ?? 0,
  };

  const displayName = safeData.player_name || safeData.name || 'Агент';
  const previewId = safeData.agent_preview_id || '';
  const threatLevel = threatLabels[safeData.threat_level ?? 'neutral'] ?? 'нейтральный';

  return (
    <Window title="Профиль агента">
      <Window.Content scrollable>
        <Section title="Профиль агента">
          <Flex align="center" gap={1}>
            <div
              style={{
                width: '120px',
                height: '120px',
                background: '#000',
                borderRadius: '4px',
                overflow: 'hidden',
              }}
            >
              {previewId ? (
                <ByondUi
                  width="100%"
                  height="100%"
                  params={{
                    id: previewId,
                    type: 'map',
                  }}
                />
              ) : (
                <Flex height="100%" align="center" justify="center" color="grey">
                  🕵️
                </Flex>
              )}
            </div>

            <Stack width="100%">
              <Box fontSize="18px" fontWeight="bold">
                {displayName}
              </Box>
              <Box color="label">Репутация: {safeData.reputation}</Box>
              <Box color="label">Текущий уровень угрозы: {threatLevel}</Box>
              <Box color="label">Доступный ТК: {safeData.total_tc}</Box>
            </Stack>
          </Flex>
        </Section>

        <Section title="Статистика">
          <Stack>
            <Box>Выполненные цели: <Box as="span" color="good">{stats.completed_goals ?? 0}</Box></Box>
            <Box>Успешных проникновений: <Box as="span" color="good">{stats.successful_infiltrations ?? 0}</Box></Box>
            <Box>Потрачено ТК: <Box as="span" color="average">{stats.spent_tc ?? 0}</Box></Box>
            <Box>Получено ТК: <Box as="span" color="good">{stats.earned_tc ?? 0}</Box></Box>
          </Stack>
        </Section>

        <Section title="Навигация">
          {tabs.map((tabKey) => (
            <Button
              key={tabKey}
              content={tabLabels[tabKey] ?? tabKey}
              selected={tab === tabKey}
              onClick={() => setTab(tabKey)}
            />
          ))}
        </Section>

        {tab === 'services' && (
          <Section title="Услуги">
            {(safeData.services?.contracts?.length ?? 0) === 0 ? (
              <Box color="label">Активных контрактов пока нет.</Box>
            ) : (
              safeData.services?.contracts.map((contract, index) => (
                <Box key={`${contract.contract_type}-${index}`} mb={0.5}>
                  {contract.contract_type} @ {contract.location} — {contract.reward_tc} ТК / {contract.reputation_reward} репутации
                </Box>
              ))
            )}
          </Section>
        )}

        {tab === 'reinforcement' && (
          <Section title="Подкрепление">
            <Box>Запрос поддержки: 4 ТК</Box>
            <Box>Широкая рассылка всем агентам</Box>
            <Box>Обновления местоположения в реальном времени</Box>
          </Section>
        )}

        {tab === 'black_market' && (
          <Section title="Чёрный рынок">
            {(safeData.services?.market_items?.length ?? 0) === 0 ? (
              <Box color="label">Позиции отсутствуют.</Box>
            ) : (
              safeData.services?.market_items.map((item) => (
                <Box key={item} mb={0.5}>{item}</Box>
              ))
            )}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};

export default TraitorReputation;
