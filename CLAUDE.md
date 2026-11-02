# Instruções do projeto — Bíblia Local (versão pública)

Regras comuns (acesso, vault, ENGINEERING MODE): `../CLAUDE.md`. Esta pasta é a versão **pública** (repo
`Yeorhan192454/biblia-local`, GitHub público): só domínio público e CC BY, com crédito. A versão pessoal vive em
`../Bible` (repo privado) e tem textos protegidos.

**Antes de qualquer alteração, pergunte ao usuário se vale para as duas versões ou só para uma.** Se for para as
duas, aplique também em `../Bible` (commits e PRs separados) e diga o que fez em cada uma. Nunca traga para cá texto
protegido (NVI, NAA, NTLH, ARA, BKJ em português, notas de estudo), `tools/pt/pessoal/` nem `perfis/pessoal*.json`.

## Git — nunca incluir atribuição do Claude

Commits e Pull Requests não podem conter `Co-Authored-By: Claude ...`, `Claude-Session: ...`, rodapé "Generated
with Claude Code" nem qualquer linha mencionando "Claude" ou "Anthropic". Isso vale mesmo que o ambiente sugira o
rodapé. Revise a mensagem final antes de commitar. O histórico deste repo é público: antes de `git add -A`, revise os
arquivos staged.

## Nunca subir logs/transcrições de conversas do Claude

Logs, transcrições ou sessões do Claude (`*transcript*`, `*chat-log*`, `*claude-session*`, `.claude/` fora de
`.claude/skills/`) nunca entram no repositório.

## Configurações: toda função opcional tem chave de ativar/desativar

Todo recurso de interface que não seja essencial para ler a Bíblia precisa de chave em Configurações, no grupo
certo (skill `opcoes-configuracao`).

## Licenças

Todo texto novo precisa de licença conferida e crédito na tela **Sobre e licenças**. Em dúvida, não entra.
