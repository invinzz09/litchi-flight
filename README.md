# Навыки Claude Code для пролётов и задач YouGile

Два навыка, работают в связке:

| Навык | Что делает | Установка |
|---|---|---|
| [**litchi-flight**](litchi-flight/) | KML участка или просто координата → контур → пролёт (змейка) в Litchi Mission Hub с проверкой рельефа и настроек | [litchi-flight/УСТАНОВКА.md](litchi-flight/УСТАНОВКА.md) |
| [**yougile-objects**](yougile-objects/) | Задача в YouGile (ссылка или номер) → чат и вложения → объекты работ → уточняющие вопросы → KML в WGS-84 → пролёты через litchi-flight | [yougile-objects/УСТАНОВКА.md](yougile-objects/УСТАНОВКА.md) |

## Как поставить

**Самый простой способ — поручить установку своему Claude.** Открыть Claude Code и вставить:

> Установи навыки из https://github.com/invinzz09/litchi-flight : скачай архив main-ветки, распакуй и скопируй папки `litchi-flight` и `yougile-objects` в `%USERPROFILE%\.claude\skills\` (создай папку, если нет). Потом покажи, что получилось.

Claude сам скачает ZIP (или сделает `git clone`, если есть git), разложит папки и подтвердит. После этого перезапустить Claude Code — навыки появятся в списке по `/`.

**Вручную:**
1. Зелёная кнопка **Code → Download ZIP**, распаковать.
2. Из архива скопировать **обе папки** `litchi-flight` и `yougile-objects` в
   `C:\Users\<имя>\.claude\skills\`
   (в итоге `…\skills\litchi-flight\SKILL.md` и `…\skills\yougile-objects\SKILL.md`).
3. Перезапустить Claude Code.

**Что понадобится помимо навыков** (навыки сами подскажут при первом запуске, чего не хватает):
- браузер Chrome или Brave с расширением **Claude in Chrome** (для Mission Hub);
- **VPN** (Mission Hub без него не открывается);
- **логин и пароль от Mission Hub организации** — вводите сами один раз в окне браузера, Claude их не спрашивает;
- **свой ключ API YouGile** — как сделать: [yougile-objects/УСТАНОВКА.md](yougile-objects/УСТАНОВКА.md), 2 минуты;
- **7-Zip** — чтобы навык распаковывал архивы из вложений YouGile.

## Версии

Все изменения — во вкладке **Commits**, стабильные состояния помечены тегами (**Tags**): `v1.0` — только litchi-flight, `v1.1` — комплект с yougile-objects. Любую версию можно открыть и скачать ZIP.

## Обратная связь

Навыки тестовые. По итогам работы навык сам попросит отзыв — файл `ОТЗЫВ_<задача>_<дата>.md` на **invin@bk.ru**.
