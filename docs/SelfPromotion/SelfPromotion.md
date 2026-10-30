# Diretrizes de Divulgação: Hackathon Meta (#BuildInPublic)
### Guia de Publicações no LinkedIn, Repositório Aberto e Políticas de Compliance da Meta

> **Visão Geral:** A Meta é uma das maiores defensoras do ecossistema de código aberto no mundo. O desenvolvimento aberto (*Build in Public*) durante o hackathon é permitido e altamente encorajado, servindo como uma alavanca de autoridade técnica profissional e visibilidade para a banca avaliadora.

---

## 1. Políticas Oficiais da Meta & Compliance Legal

### A. Repositório Aberto (Open Source)
* **Permissão:** O código pode (e na maioria dos critérios de avaliação, deve) ser público no GitHub.
* **Licenciamento Recomendado:** Use licenças abertas permissivas como **MIT License** ou **Apache 2.0**, compatíveis com o ecossistema da Meta e da comunidade Flutter.
* **Higiene de Segurança:** **NUNCA** realize commits com chaves de API, tokens de acesso ou URLs de endpoints restritos fornecidos no email de aprovação. Utilize variáveis de ambiente via `.env` adicionado obrigatoriamente no `.gitignore`.

### B. Propriedade Intelectual (IP)
* **Seus Direitos:** O código, arquitetura e direitos autorais do projeto **FlutterGuard-AI** continuam sendo **100% de sua propriedade**.
* **Direitos da Meta:** A Meta recebe apenas o direito não exclusivo de testar, avaliar a submissão e exibir trechos do projeto/vídeo-pitch em materiais promocionais, lives de encerramento e posts institucionais de premiação.

### C. Uso da Marca e Imagem da Meta
* **Pode Fazer:**
  * Declarar com orgulho: *"Fui selecionado/aprovado para o Hackathon Global da Meta..."*
  * Usar: *"Construindo uma solução para Flutter utilizando a tecnologia de IA da Meta (Llama 3 / Meta Muse / SAM)..."*
  * Compartilhar capturas de tela do desenvolvimento, arquitetura e logs de testes.
* **NÃO Pode Fazer:**
  * Não afirme que o projeto é uma "parceria oficial" ou "financiado/patrocinado diretamente pela Meta Inc.". Você é um participante oficial do hackathon.
  * Não altere proporções, cores ou crie derivações não autorizadas da logo da Meta. Prefira usar artes próprias com a menção textual ou os banners oficiais do evento.

---

## 2. Calendário Estratégico de Posts para o LinkedIn (10 Dias)

Para gerar tração profissional e engajamento sem tomar tempo da codificação, utilize esta cadência enxuta de 6 posts estratégicos ao longo dos 10 dias:

```
[Dia 1] O Anúncio ──> [Dia 3] Arquitetura ──> [Dia 5] O Desafio Técnico
                             │
                             ▼
[Dia 10] O Pitch  <── [Dia 9] As Evidências <── [Dia 7] Demonstração Visual
```

---

### Detalhamento dos Posts

#### 📢 Post 1 (Dia 1): O Anúncio da Seleção & A Dor de Mercado
* **Gancho:** *"Aprovado no Hackathon da Meta! Durante os próximos 10 dias vou construir o FlutterGuard-AI..."*
* **Problema abordado:** Todo mundo usa IA para gerar código Flutter, mas quem valida que esse código não quebrou o ciclo de vida do widget ou gerou telas com `RenderFlex overflowed`?
* **A Solução:** Um harness determinístico e reativo alimentado pela IA da Meta.
* **Chamada para Ação (CTA):** Acompanhe aqui os bastidores dessa jornada.

#### 🏛️ Post 2 (Dia 3): Metodologia & Arquitetura (SDD em Ação)
* **Gancho:** *"Por que não deixamos a IA escrever código livremente no Flutter?"*
* **Tema:** Explicar o conceito de Spec-Driven Development (SDD) e o ciclo Red/Green de testes determinísticos.
* **Visual:** Diagrama de fluxo do FlutterGuard (Markdown ou infográfico limpo da esteira de qualidade).

#### 🛠️ Post 3 (Dia 5): O Desafio Técnico (Bastidores da Engenharia)
* **Gancho:** *"O que acontece quando você tenta analisar a Árvore Sintática Abstrata (AST) do Dart com IA?"*
* **Tema:** Compartilhar um desafio real de engenharia superado na integração com os modelos da Meta e como a esteira se recuperou do erro.
* **Efeito:** Transmite humildade e senioridade técnica real.

#### 👁️ Post 4 (Dia 7): O Fator "Uau" (A Mágica Visual com SAM / Meta Vision)
* **Gancho:** *"Compiladores leem texto, mas usuários enxergam pixels. Veja a IA da Meta auditando uma UI do Flutter em tempo real."*
* **Formato:** Um vídeo curto (30 a 45 segundos) ou GIF mostrando o widget renderizado e a IA apontando o overflow de tela antes do deploy.

#### 📊 Post 5 (Dia 9): Métricas & Confiabilidade Material
* **Gancho:** *"Na engenharia de verdade, 'confia em mim' não é evidência. Veja como medimos a qualidade do código gerado por IA."*
* **Tema:** Exibir o log de rastreabilidade determinística (`evidence.jsonl`), gráficos de cobertura e testes aprovados.

#### 🏆 Post 6 (Dia 10): A Submissão Oficial & Pitch
* **Gancho:** *"10 dias intensos. Submissão concluída no Hackathon da Meta!"*
* **Tema:** Agradecimento à organização do Hackathon, link do repositório público no GitHub com a documentação completa e convite para a comunidade de Flutter testar e dar feedback.

---

## 3. Hashtags e Marcações Recomendadas

Sempre utilize as marcações abaixo para que os algoritmos de recomendação e os curadores da Meta encontrem suas publicações:

* **Tags Oficiais:** `#MetaAI` `#Llama3` `#MetaOpenSource` `#Hackathon`
* **Tags Técnicas:** `#FlutterDev` `#DartLang` `#AgenticAI` `#SoftwareEngineering` `#QualityAssurance`
* **Comunidade:** `#BuildInPublic` `#TechCommunity` `#OpenSource`

---

## 4. Dica de Ouro: Geração dos Posts com Suporte da IA

Para não perder tempo redigindo posts durante os dias de código intenso:
* O agente `editorial` do repositório pode transformar as entregas das histórias (`docs/stories/`) e as evidências (`evidence.jsonl`) em rascunhos de posts prontos para você copiar e colar no LinkedIn em menos de 2 minutos.

