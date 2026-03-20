# Resumo da conversa: TTS, clonagem de voz e transcrição

Este documento resume os testes que fizemos nesta conversa com modelos de texto para fala, clonagem de voz e voz para texto.

## Objetivo

Explorar opções locais, sem gastar créditos externos, para:

- converter texto em áudio
- reproduzir áudio com sotaque brasileiro
- clonar a sua própria voz com uma amostra curta
- transcrever áudio para texto
- comparar velocidade e qualidade entre modelos

## Arquivos de referência usados

- Amostra de voz do usuário: `/Users/yuri/Downloads/Avenida Rebouças, 1480.m4a`
- Transcrição local da amostra: `/private/tmp/ref_transcribe/Avenida_Rebouas_1480.transcript.txt`

O conteúdo do TXT foi usado no teste final de clonagem, exatamente como estava no arquivo.

## Modelos testados

| Modelo | Tipo | Uso principal no teste | Resultado prático |
|---|---|---|---|
| `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit` | TTS com clonagem por referência | Clonar voz com `ref_audio` + `ref_text` | Funcionou bem para clonagem; foi o melhor para aproximar a sua voz |
| `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-4bit` | TTS com vozes fixas | Texto para voz com vozes predefinidas | Bom para síntese geral, mas não foi o melhor caminho para clonagem direta |
| `Kokoro 82M` | TTS leve | Texto para voz rápido em pt-BR | Muito rápido e muito bom para leitura natural |
| `Piper` com `pt_BR-cadu-medium` | TTS leve | Texto para voz em português brasileiro | Mais rápido que Kokoro em um benchmark e com voz natural em pt-BR |
| `Fish Audio S2 Pro` | TTS de grande porte | Teste de compatibilidade local | Carregou, mas ficou pesado demais para o Mac de 8 GB |
| `faster-whisper` | Voz para texto | Transcrição local da amostra | Funcionou bem para extrair a legenda da sua gravação sem usar API externa |

## O que cada modelo fez melhor

| Caso de uso | Melhor opção encontrada | Observação |
|---|---|---|
| Texto para voz rápido | `Piper` | Pequena vantagem no benchmark de velocidade |
| Texto para voz em português brasileiro | `Piper` | Voz `pt_BR-cadu-medium` soou mais natural no começo |
| Texto para voz com boa naturalidade geral | `Kokoro` | Muito leve e rápido, com `pm_alex` e `pm_santa` para pt-BR |
| Clonagem da sua voz | `Qwen3-TTS-Base` | Foi o caminho que realmente aceitou a sua gravação como referência |
| Voz para texto local | `faster-whisper` | Serve para extrair `ref_text` da amostra sem pagar serviço externo |

## Benchmarks de velocidade

### Kokoro vs Piper

Texto usado:

> Olá, este é um teste de velocidade para comparar Piper e Kokoro no português brasileiro.

| Modelo | Voz | Tempo de geração | Duração do áudio | RTF |
|---|---|---:|---:|---:|
| Kokoro | `pm_santa` | `1.398 s` | `5.425 s` | `0.258` |
| Piper | `pt_BR-cadu-medium` | `1.158 s` | `5.712 s` | `0.203` |

Leitura:

- `Piper` ficou um pouco mais rápido nesse teste.
- `Kokoro` continuou muito rápido e soou muito bem.
- Como as durações finais foram diferentes, o RTF foi a comparação mais justa.
- No teste final de reprodução, o `Piper` também ficou muito bom em português brasileiro, não só rápido.

### Qwen3-TTS

Rodadas relevantes:

| Teste | Entrada | Tempo de processamento | Duração do áudio | Memória pico |
|---|---|---:|---:|---:|
| Qwen3 simples | Texto curto | `8.296 s` de geração | não fixado aqui | não registrado |
| Qwen3 com referência pt-BR | Texto curto + `ref_audio` brasileiro | `5.706 s` | não fixado aqui | não registrado |
| Qwen3 clonagem inicial | Texto curto + referência | `17.75 s` | `6.080 s` | `7.04 GB` |
| Qwen3 clonagem com transcrição exata | Texto mais longo | `27.64 s` | `10.560 s` | `7.45 GB` |
| Qwen3 usando o TXT inteiro como texto de saída | Texto do TXT completo | `44.08 s` | `25.360 s` | `9.13 GB` |

Leitura:

- O Qwen3 foi o melhor para clonagem.
- Ele ficou bem melhor quando a referência era uma voz brasileira limpa.
- Usar o conteúdo exato do TXT como `text` final ajudou a manter coerência e naturalidade.

## Vozes e sotaque

### Kokoro

Vozes testadas em pt-BR:

- `pm_alex`
- `pm_santa`

O que observamos:

- as duas soam em português brasileiro
- a diferença principal é timbre
- `pm_alex` foi uma boa primeira escolha

### Piper

Voz usada:

- `pt_BR-cadu-medium`

O que observamos:

- muito natural para pt-BR
- ótimo equilíbrio entre qualidade e velocidade
- boa opção quando a prioridade é ler texto com sotaque brasileiro claro

### Qwen3-TTS

O melhor resultado saiu quando:

- o `ref_audio` era a sua própria gravação
- o `ref_text` era exatamente a transcrição do áudio
- o texto de saída era longo o suficiente para testar a fidelidade

## Clonagem de voz

O caminho que funcionou foi este:

1. usar uma gravação sua como `ref_audio`
2. usar a transcrição exata dessa gravação como `ref_text`
3. rodar o modelo `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit`
4. gerar o novo áudio a partir de outro texto, ou do próprio texto do TXT

### Comparação final de clonagem e sotaque

| Modelo | Clonagem da sua voz | Sotaque pt-BR | Velocidade |
|---|---|---|---:|
| Qwen3-TTS Base | melhor | melhor | mais lento |
| KokoClone | bom, mas não perfeito | ok, porém com sotaque misto | intermediário |
| Kokoro | não clona | muito bom | rápido |
| Piper | não clona | muito bom | muito rápido |

Leitura final:

- `Qwen3-TTS Base` foi o melhor para parecer com a sua voz.
- `Piper` ficou muito forte em português brasileiro e acabou sendo uma ótima opção prática.
- `KokoClone` funcionou, mas ficou abaixo do Qwen3 em fidelidade e sotaque.
- `Kokoro` foi excelente para voz pronta, mas o teste ouvido foi a voz `pm_santa`, não clonagem da sua voz.

### Arquivos gerados

- [qwen3_clone_from_my_voice_000.wav](/tmp/qwen3_clone_from_my_voice_000.wav)
- [qwen3_clone_exact_transcript_000.wav](/tmp/qwen3_clone_exact_transcript_000.wav)
- [qwen3_transcript_as_text_000.wav](/tmp/qwen3_transcript_as_text_000.wav)

## Transcrição local

Para transformar voz em texto, usamos `faster-whisper` localmente.

Isso serviu para:

- extrair o `ref_text` da amostra
- evitar custo externo
- manter o fluxo totalmente local

## Whisper.cpp

O repositório `whisper.cpp` também faz parte deste workspace e é relevante para o contexto do projeto.

No que diz respeito a esta conversa:

- `whisper.cpp` representa a base local de STT disponível no código do projeto
- a transcrição da amostra que usamos aqui foi feita com `faster-whisper`, porque foi o caminho mais rápido para extrair `ref_text`
- a presença do `whisper.cpp` no workspace mostra que o projeto já tem uma estrutura forte para voz para texto local

Em termos práticos:

- `whisper.cpp` é uma opção importante se você quiser consolidar tudo num stack mais controlado e nativo
- `faster-whisper` foi a escolha prática para esta sessão, mas `whisper.cpp` continua sendo um componente central do ambiente

## Conclusões práticas

### Melhor para velocidade

1. `Piper`
2. `Kokoro`
3. `Qwen3-TTS`

### Melhor para português brasileiro natural

1. `Piper` com `pt_BR-cadu-medium`
2. `Kokoro` com `pm_alex` ou `pm_santa`
3. `Qwen3-TTS` quando a referência de voz brasileira estava boa

### Melhor para clonar sua voz

1. `Qwen3-TTS-Base`
2. `Fish Audio S2 Pro` como alternativa, mas pesado demais no Mac testado
3. `KokoClone` como alternativa funcional, mas com sotaque menos brasileiro que o Qwen3

### Melhor fluxo local sem gastar créditos

1. gravar a sua voz
2. transcrever localmente com `faster-whisper`
3. usar a transcrição como `ref_text`
4. gerar áudio com `Qwen3-TTS-Base`

## Observações finais

- O modelo `CustomVoice` do Qwen3 foi útil para voz sintetizada, mas o caminho certo para clonagem foi a variante `Base`.
- `Kokoro` foi uma ótima descoberta para leitura rápida em pt-BR.
- `Piper` foi o mais previsível para português brasileiro e acabou ficando muito bom também na escuta final.
- O primeiro WAV do Piper saiu vazio por um erro de geração, mas a versão corrigida (`compare_piper_fixed.wav`) funcionou corretamente.
- O arquivo final do texto transcrito inteiro ficou bom quando a saída usou o próprio conteúdo do TXT.
