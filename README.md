# Добро пожаловать в репозиторий CorvaxStation по игре Space Station 13

[![Build Status](https://github.com/corvax-team/CorvaxStation/workflows/CI%20Suite/badge.svg)](https://github.com/corvax-team/CorvaxStation/actions?query=workflow%3A%22CI+Suite%22)
[![Percentage of issues still open](https://isitmaintained.com/badge/open/corvax-team/CorvaxStation.svg)](https://isitmaintained.com/project/corvax-team/CorvaxStation "Percentage of issues still open")
[![Average time to resolve an issue](https://isitmaintained.com/badge/resolution/corvax-team/CorvaxStation.svg)](https://isitmaintained.com/project/corvax-team/CorvaxStation "Average time to resolve an issue")
![Coverage](https://img.shields.io/badge/coverage---4%25-red.svg)

[![resentment](.github/images/badges/built-with-resentment.svg)](.github/images/comics/131-bug-free.png) [![technical debt](.github/images/badges/contains-technical-debt.svg)](.github/images/comics/106-tech-debt-modified.png) [![forinfinityandbyond](.github/images/badges/made-in-byond.gif)](https://www.reddit.com/r/SS13/comments/5oplxp/what_is_the_main_problem_with_byond_as_an_engine/dclbu1a)

| Website          | Link                                                                                         |
| ---------------- | -------------------------------------------------------------------------------------------- |
| Website          | [https://corvax.beer](https://corvax.beer)                                                   |
| Code             | [https://github.com/corvax-team/CorvaxStation](https://github.com/corvax-team/CorvaxStation) |
| Wiki             | [https://bs.ss220.club](https://bs.ss220.club)                                               |
| Codedocs         | [https://corvax-team.github.io/CorvaxStation/](https://corvax-team.github.io/CorvaxStation/) |
| Corvax Discord   | [https://discord.gg/6WWapXwDkC](https://discord.gg/6WWapXwDkC)                               |
| Coderbus Discord | [https://discord.gg/Vh8TJp9](https://discord.gg/Vh8TJp9)                                     |

## Загрузка

[Загрузка](.github/guides/DOWNLOADING.md)

[Запуск сервера](.github/guides/RUNNING_A_SERVER.md)

[Карты и руины](.github/guides/MAPS_AND_AWAY_MISSIONS.md)

## Компиляция

**Быстрый способ**. Найдите `bin/server.cmd` в этой папке и дважды щелкните по нему, чтобы автоматически собрать и запустить сервер на порту 1337.

**Долгий способ**. Найдите `bin/build.cmd` в этой папке и дважды щелкните по нему, чтобы начать сборку. Она состоит из нескольких шагов и может занять около 1-5 минут для компиляции. Если оно закроется, это значит, что работа завершена. Затем вы можете [настроить сервер](.github/guides/RUNNING_A_SERVER.md) как обычно, открыв `tgstation.dmb` в DreamDaemon.

**Сборка tgstation напрямую в DreamMaker устарела и может вызвать ошибки**, такие как `‘tgui.bundle.js’: не удается найти файл`.

**[Как компилировать в VSCode и другие варианты сборки](tools/build/README.md).**

## Начало работы

Для руководств по вкладу смотрите [Руководства для участников](.github/CONTRIBUTING.md).

Для начала работы (окружение разработчика, компиляция) смотрите документ HackMD [здесь](https://hackmd.io/@tgstation/HJ8OdjNBc#tgstation-Development-Guide).

Для общей документации по дизайну смотрите [HackMD](https://hackmd.io/@tgstation).

## LICENSE

All code after [commit 333c566b88108de218d882840e61928a9b759d8f on 2014/31/12 at 4:38 PM PST](https://github.com/corvax-team/CorvaxStation/commit/333c566b88108de218d882840e61928a9b759d8f) is licensed under [GNU AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html).

All code before [commit 333c566b88108de218d882840e61928a9b759d8f on 2014/31/12 at 4:38 PM PST](https://github.com/corvax-team/CorvaxStation/commit/333c566b88108de218d882840e61928a9b759d8f) is licensed under [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html).
(Including tools unless their readme specifies otherwise.)

See LICENSE and GPLv3.txt for more details.

The TGS DMAPI is licensed as a subproject under the MIT license.

See the footer of [code/\_\_DEFINES/tgs.dm](./code/__DEFINES/tgs.dm) and [code/modules/tgs/LICENSE](./code/modules/tgs/LICENSE) for the MIT license.

All assets including icons and sound are under a [Creative Commons 3.0 BY-SA license](https://creativecommons.org/licenses/by-sa/3.0/) unless otherwise indicated.
