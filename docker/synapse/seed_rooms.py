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
            ("alice", "Também. Vamos testar o aplicativo?"),
            ("bob", "Bora! Já estou com o cliente aberto."),
            ("alice", "Perfeito. Me avisa quando receber esta mensagem."),
            ("bob", "Recebi! A conversa está chegando em tempo real."),
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
            ("carol", "Bom dia! Já li a especificação do projeto."),
            ("dave", "Bom dia. Alguém pode revisar o layout das telas?"),
            ("bob", "Eu reviso hoje à tarde."),
            ("alice", "Combinado. Carol, você fica com a lista de salas?"),
            ("carol", "Fico sim. Começo pelo avatar com a inicial do nome."),
            ("dave", "Eu cuido do campo de envio e do estado das mensagens."),
        ],
    },
    {
        "alias": "projeto-matrix",
        "name": "Projeto Matrix",
        "topic": "Integração com o Matrix Rust SDK",
        "creator": "carol",
        "members": ["alice", "bob"],
        "messages": [
            ("carol", "Subi a primeira versão da integração com o SDK."),
            ("alice", "Ótimo! O login e a sessão já estão funcionando."),
            ("bob", "Falta o sync e a lista de salas."),
            ("carol", "Esse é o próximo passo. Vou usar um stream do Rust."),
        ],
    },
    {
        "alias": "bob-carol",
        "name": "Bob e Carol",
        "creator": "bob",
        "members": ["carol"],
        "messages": [
            ("bob", "Carol, você viu o documento de requisitos?"),
            ("carol", "Vi sim. O wireframe ficou parecido com o Telegram."),
            ("bob", "Isso mesmo. Lista à esquerda e conversa à direita."),
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
