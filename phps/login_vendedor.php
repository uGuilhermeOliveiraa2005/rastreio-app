<?php
header('Content-Type: application/json');
include 'conexao.php';

$email = $_POST['email'];
$senha = $_POST['senha'];

$stmt = $conn->prepare("SELECT unique_id, nome, senha_hash FROM vendedores WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    if (password_verify($senha, $row['senha_hash'])) {
        echo json_encode(["status" => "sucesso", "id" => $row['unique_id'], "nome" => $row['nome']]);
    } else {
        echo json_encode(["status" => "erro", "msg" => "Senha incorreta"]);
    }
} else {
    echo json_encode(["status" => "erro", "msg" => "Usuário não encontrado"]);
}
$conn->close();
?>