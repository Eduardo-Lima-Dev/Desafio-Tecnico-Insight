import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://synapse:8008/_matrix/client/v3"
SERVER = "localhost"
PASSWORD = "senha123"

USERS = {
    "alice": "Alice",
    "bob": "Bob",
    "carol": "Carol",
    "dave": "Dave",
}

HISTORY = [
    ("alice" if i % 2 == 0 else "bob", f"Mensagem {i:02d} do histórico de teste")
    for i in range(1, 81)
]

ROOMS = [
    {
        "alias": "alice-bob",
        "name": "Alice e Bob",
        "creator": "alice",
        "members": ["bob"],
        "messages": [
            ("alice", "Oi, Bob! Tudo bem?"),
            ("bob", "Tudo ótimo, Alice. E você?"),
            ("alice", "Também. E aí, viu o jogo de ontem?"),
            ("bob", "Vi sim! Que final emocionante."),
            ("alice", "Demais! Domingo vamos assistir juntos?"),
            ("bob", "Combinado. Eu levo o refrigerante."),
        ],
    },
    {
        "alias": "equipe-insight",
        "name": "Equipe Insight",
        "topic": "Sala geral da equipe",
        "creator": "alice",
        "members": ["bob", "carol", "dave"],
        "messages": [
            ("alice", "Bom dia, pessoal! Bem-vindos à sala da equipe."),
            ("carol", "Bom dia! Subi o módulo de pedidos no NestJS."),
            ("dave", "Bom dia. Alguém pode revisar o PR da API de clientes?"),
            ("bob", "Eu reviso hoje à tarde."),
            ("alice", "Combinado. Carol, você fica com a autenticação JWT?"),
            ("carol", "Fico sim. Começo pelo guard e pelos testes."),
            ("dave", "Eu cuido da migração do Prisma e do docker-compose."),
        ],
    },
    {
        "alias": "api-pedidos",
        "name": "API de Pedidos",
        "topic": "Back-end em NestJS com PostgreSQL",
        "creator": "carol",
        "members": ["alice", "bob"],
        "messages": [
            ("carol", "Subi a primeira versão da API de pedidos em NestJS."),
            ("alice", "Ótimo! O CRUD de clientes já está funcionando."),
            ("bob", "Falta o endpoint de pagamentos e a documentação com Swagger."),
            ("carol", "Esse é o próximo passo. Vou usar um interceptor para os logs."),
        ],
    },
    {
        "alias": "bob-carol",
        "name": "Bob e Carol",
        "creator": "bob",
        "members": ["carol"],
        "messages": [
            ("bob", "Carol, você vai no treino de vôlei amanhã?"),
            ("carol", "Vou sim! Quinta é dia de quadra."),
            ("bob", "Boa! Chego um pouco mais cedo para ajudar com a rede."),
        ],
    },
    {
        "alias": "almoco-sexta",
        "name": "Almoço de sexta",
        "topic": "Combinados do almoço",
        "creator": "dave",
        "members": ["alice", "carol"],
        "messages": [
            ("dave", "Pessoal, onde vamos almoçar na sexta?"),
            ("alice", "Pode ser o restaurante perto do escritório."),
            ("carol", "Por mim está ótimo. Às 12h30?"),
            ("dave", "Fechado, às 12h30."),
        ],
    },
    {
        "alias": "futebol-quinta",
        "name": "Futebol de quinta",
        "topic": "Racha semanal",
        "creator": "dave",
        "members": ["alice", "bob", "carol"],
        "messages": [
            ("dave", "Galera, racha na quinta às 20h. Quem vai?"),
            ("bob", "Estou dentro!"),
            ("carol", "Eu vou, mas só se for no society."),
            ("alice", "Conta comigo também. Quem leva a bola?"),
            ("dave", "Eu levo a bola e os coletes."),
            ("bob", "Fechado. Time branco contra o colorido?"),
        ],
    },
    {
        "alias": "volei-turma",
        "name": "Vôlei da turma",
        "topic": "Treinos e jogos de vôlei",
        "creator": "carol",
        "members": ["alice", "bob", "dave"],
        "messages": [
            ("carol", "Treino de vôlei amanhã às 19h na quadra da escola."),
            ("alice", "Boa! Vou levar a bola nova."),
            ("dave", "Pode contar comigo, só vou chegar um pouco atrasado."),
            ("bob", "Vamos formar dois times de seis?"),
            ("carol", "Isso! Quem chegar primeiro monta a rede."),
        ],
    },
    {
        "alias": "duvidas-nestjs",
        "name": "Dúvidas de NestJS",
        "topic": "Perguntas e dicas de back-end",
        "creator": "bob",
        "members": ["alice", "carol", "dave"],
        "messages": [
            (
                "bob",
                "Alguém sabe a melhor forma de validar o corpo das requisições no NestJS?",
            ),
            ("dave", "Usa o ValidationPipe junto com o class-validator nos DTOs."),
            (
                "alice",
                "E ativa o whitelist para descartar os campos que não estão no DTO.",
            ),
            ("carol", "Dica: o transform converte os tipos automaticamente."),
            ("bob", "Valeu, time! Vou ajustar isso ainda hoje."),
        ],
    },
    {
        "alias": "churrasco",
        "name": "Churrasco do fim de semana",
        "topic": "Organização do churrasco",
        "creator": "alice",
        "members": ["bob", "carol", "dave"],
        "messages": [
            ("alice", "Pessoal, churrasco no sábado lá em casa. Quem vem?"),
            ("dave", "Eu vou! Levo o carvão."),
            ("carol", "Levo a sobremesa e o refrigerante."),
            ("bob", "Posso trazer a carne? A partir de que horas?"),
            ("alice", "Pode ser a partir das 13h. Traz também um pão de alho!"),
            ("dave", "Perfeito, até sábado."),
        ],
    },
    {
        "alias": "filmes-series",
        "name": "Filmes e séries",
        "topic": "Indicações e maratonas",
        "creator": "carol",
        "members": ["alice", "dave"],
        "messages": [
            ("carol", "Vocês assistiram a série nova que saiu essa semana?"),
            ("alice", "Ainda não, mas ouvi falar bem. Sem spoiler!"),
            ("dave", "Vi os três primeiros episódios, vale muito a pena."),
            ("carol", "Marcamos uma maratona no domingo, então?"),
        ],
    },
    {
        "alias": "pipeline-deploy",
        "name": "Pipeline e deploy",
        "topic": "CI/CD e infraestrutura",
        "creator": "dave",
        "members": ["alice", "bob"],
        "messages": [
            ("dave", "O deploy da API no ambiente de testes passou no pipeline."),
            ("bob", "Boa! O container do Postgres subiu certinho?"),
            ("dave", "Subiu sim, o docker-compose está funcionando."),
            ("alice", "Vou rodar os testes de integração agora."),
        ],
    },
    {
        "alias": "historico-longo",
        "name": "Histórico longo",
        "topic": "Sala com muitas mensagens para testar a paginação",
        "creator": "alice",
        "members": ["bob"],
        "messages": HISTORY,
    },
]


def call(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(6):
        request = urllib.request.Request(BASE + path, data=data, method=method)
        request.add_header("Content-Type", "application/json")
        if token:
            request.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            try:
                payload = json.load(error)
            except ValueError:
                payload = {}
            if error.code == 429:
                time.sleep(payload.get("retry_after_ms", 500) / 1000 + 0.1)
                continue
            return error.code, payload
    return 429, {}


def login(user):
    status, payload = call(
        "POST",
        "/login",
        body={
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": user},
            "password": PASSWORD,
        },
    )
    if status != 200:
        sys.exit(f"Falha no login de {user}: {status} {payload}")
    return payload["access_token"]


def room_exists(alias):
    full_alias = urllib.parse.quote(f"#{alias}:{SERVER}", safe="")
    status, _ = call("GET", f"/directory/room/{full_alias}")
    return status == 200


def seed_room(room, tokens):
    if room_exists(room["alias"]):
        print(f"Sala '{room['name']}' já existe, mantendo.")
        return

    invites = [f"@{member}:{SERVER}" for member in room["members"]]
    body = {
        "room_alias_name": room["alias"],
        "name": room["name"],
        "preset": "private_chat",
        "invite": invites,
    }
    if "topic" in room:
        body["topic"] = room["topic"]

    status, payload = call("POST", "/createRoom", tokens[room["creator"]], body)
    if status != 200:
        sys.exit(f"Falha ao criar '{room['name']}': {status} {payload}")
    room_id = payload["room_id"]
    quoted_id = urllib.parse.quote(room_id, safe="")

    for member in room["members"]:
        status, payload = call("POST", f"/join/{quoted_id}", tokens[member], {})
        if status != 200:
            sys.exit(f"{member} não entrou em '{room['name']}': {status} {payload}")

    for index, (sender, text) in enumerate(room["messages"]):
        status, payload = call(
            "PUT",
            f"/rooms/{quoted_id}/send/m.room.message/seed-{room['alias']}-{index}",
            tokens[sender],
            {"msgtype": "m.text", "body": text},
        )
        if status != 200:
            sys.exit(f"Falha ao enviar mensagem em '{room['name']}': {status} {payload}")

    print(f"Sala '{room['name']}' criada com {len(room['messages'])} mensagens.")


def main():
    tokens = {user: login(user) for user in USERS}

    for user, display_name in USERS.items():
        quoted_user = urllib.parse.quote(f"@{user}:{SERVER}", safe="")
        call(
            "PUT",
            f"/profile/{quoted_user}/displayname",
            tokens[user],
            {"displayname": display_name},
        )

    for room in ROOMS:
        seed_room(room, tokens)

    print("Seed concluído.")


if __name__ == "__main__":
    main()
