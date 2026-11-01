# Project Overview: FlutterGuard AI

## 1. O Problema Real: O Gargalo da IA no Ecossistema Flutter / Dart

O avanço dos Modelos de Linguagem de Grande Porte (LLMs) transformou a velocidade de escrita de código, mas gerou um efeito colateral crítico na engenharia de software: **o código gerado parece correto na sintaxe, mas é frágil, arquiteturalmente degradado e perigoso em produção**.

Em ecossistemas fortemente reativos e orientados a árvores de renderização como o **Flutter**, esse problema é amplificado de forma dramática:

1. **Poluição da Widget Tree & Rebuilds Desnecessários:**  
   LLMs rotineiramente instanciam controllers (`TextEditingController`, `AnimationController`, etc.) ou chamam regras de negócio pesadas diretamente dentro do método `build()`. Isso provoca vazamentos de memória e dezenas de rebuilds por segundo.
2. **State Anti-Patterns & Descolamento de Estado:**  
   A IA mistura frameworks reativos (Riverpod, Bloc, Provider) sem respeitar a imutabilidade, deixando listeners órfãos e chamando mutações assíncronas em contextos desmontados (`BuildContext across async gaps`), gerando crashes em tempo de execução.
3. **Complacência e "Testes Fraudulentos":**  
   Quando solicitada a criar testes, a IA gera primeiro o código visual e depois inventa testes unitários superficiais cheios de mocks complacentes. Os testes passam no terminal, mas não cobrem nenhum caso limite de negócio.
4. **Cegueira Visual e Layout Shifts:**  
   Linters tradicionais (`dart analyze`, DCM) analisam apenas texto. Eles são incapazes de perceber que um botão foi cortado pela borda, que uma lista causou `RenderFlex overflowed` em uma tela de 800×600 ou que um diálogo sobrepôs elementos vitais.

---

## 2. A Solução: FlutterGuard AI

O **FlutterGuard AI** transforma o ciclo de desenvolvimento com IA de um processo passivo de "gerar texto e torcer para funcionar" em um **Harness Agêntico de Loop Fechado (*Closed-Loop Agentic Harness*)**.

Em vez de ser apenas um linter ou um conjunto estático de prompts, o framework opera como uma **barreira reativa e bloqueante** que:

* **Exige especificação formal antes do código:** A IA é impedida de escrever código de produto até que contratos de estado e testes que falham (**RED stage**) estejam formalizados.
* **Inspeciona a AST em tempo real:** Barreiras estáticas baseadas no analisador do Dart interceptam violações de arquitetura limpa e antipadrões de estado antes mesmo da execução.
* **Auto-correção com Receitas Canônicas:** Ao detectar um erro, o framework não apenas reclama; ele injeta uma receita cirúrgica no prompt do agente com exemplos canônicos (*Before / After*), forçando a convergência em 1 ou 2 turnos.
* **Auditoria Visual Multimodal:** Renderiza o widget de forma headless e utiliza modelos de segmentação visual para auditar as caixas delimitadoras (*bounding boxes*), margens e proporções da tela.

---

## 3. O Que o Framework Resolve

| Gargalo Atual com IA | Como o FlutterGuard AI Resolve |
| :--- | :--- |
| **Alucinação de código sem testes** | Força o ciclo **Spec-Driven Development (SDD)**: o agente só pode codificar contra testes unitários que falham previamente. |
| **Lógica de negócio acoplada na UI** | Barreira de AST bloqueia importações e chamadas de persistência/serviços dentro de widgets de visualização. |
| **Erros assíncronos e vazamento de memória** | Verificador de integridade assíncrona exige verificações explícitas de ciclo de vida (`mounted`, `dispose`) e imutabilidade de estado. |
| **Bugs de layout silenciosos (`RenderFlex`)** | Testes de widget headless em resoluções adversárias acionam inspeção visual multimodal para barrar quebras de tela. |
| **Loop infinito de tentativa e erro da IA** | Injeção Just-in-Time da receita canônica correta contendo a solução exata que um engenheiro sênior aplicaria. |

---

## 4. Filosofia Operacional

> **"Fail-Closed by Design" (Falha Fechada por Padrão):**  
> Se houver qualquer dúvida, warning de compilador, quebra de teste ou inconformidade visual, o framework bloqueia o avanço e reverte a alteração causadora. O código só atinge o repositório quando provar deterministicamente que está pronto para produção.

### 4.1. Validação Externa da Indústria: A Convergência com Clean Code & `ub-mode`
A tese de que agentes de IA não podem operar sem gates determinísticos rígidos recebeu validação expressiva da liderança mundial de engenharia de software com o lançamento do **[ub-mode](https://github.com/unclebob/ub-mode)** por Robert C. Martin ("Uncle Bob").

O FlutterGuard-AI compartilha da mesma premissa matemática do Uncle Bob (rejeição a avaliações subjetivas de código, TDD estrito e métricas objetivas de complexidade e mutação), expandindo essa fronteira para o ecossistema móvel e multimodal:
* **Métrica CRAP (< 10) e Verificação de Duplicação** integradas à AST do Dart.
* **Protocolo "Attack the Premise"** para impedir loops de alucinação no ciclo de autocura.
* **Extensão Multimodal:** Além do código e texto, o FlutterGuard adiciona o que o `ub-mode` não alcança: profiling de rebuilds de frames e auditoria visual de telas renderizadas (SAM 3.1).
* *Para o detalhamento técnico e referências, veja:* [Clean Code Deterministic Gates](file:///c:/_Projetos/Agentic%20AI%20Engineer/ferramentas%20de%20estudo/FlutterGuard-AI/docs/Methodology/CleanCodeDeterministicGates.md).

---

## 5. Diretrizes de Idioma & Compliance do Hackathon Global

Por se tratar de uma competição global com banca avaliadora internacional da Meta, o projeto adota uma política de idiomas clara para maximizar o impacto técnico sem comprometer a agilidade de desenvolvimento:

| Componente | Idioma Oficial | Justificativa / Finalidade |
| :--- | :---: | :--- |
| **Formulário de Submissão** | 🇺🇸 **Inglês** | Avaliado diretamente pela banca executiva da Meta nos EUA. Textos já consolidados no blueprint. |
| **Vídeo Pitch Demo (2 min)** | 🇺🇸 **Inglês** | Narração e legendas oficiais em inglês para avaliação de impacto e clareza. |
| **README.md Principal (GitHub)** | 🇺🇸 **Inglês** | Vitrine pública do repositório avaliada pelos jurados. Mantém link opcional para `README.pt-BR.md`. |
| **Código-Fonte, Commits & CLI** | 🇺🇸 **Inglês** | Padrão universal do Dart/Flutter: nomes de classes, métodos, testes, commits e saídas do CLI/MCP. |
| **Documentos Internos (`docs/`)** | 🇧🇷 **Português** | Mantidos em português durante a maratona para máxima velocidade e clareza de raciocínio da equipe. |
| **Divulgação LinkedIn** | 🇧🇷 **Português** | Foco na construção de autoridade local (#BuildInPublic), utilizando as tags oficiais da Meta em inglês. |

> **Estratégia de Encerramento (Dia 9/10):**  
> O desenvolvimento diário é feito em código com nomenclatura em inglês e raciocínio/documentação interna em português. Nos dias finais, gera-se a versão final em inglês do `README.md` na raiz e grava-se a demo narrada em inglês conforme o roteiro oficial.

