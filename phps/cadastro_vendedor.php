<?php
header('Content-Type: application/json; charset=utf-8');
include 'conexao.php';

$nome = $_POST['nome'];
$email = $_POST['email'];
$senha = $_POST['senha'];

$check = $conn->prepare("SELECT id FROM vendedores WHERE email = ?");
$check->bind_param("s", $email);
$check->execute();
if ($check->get_result()->num_rows > 0) {
    echo json_encode(["status" => "erro", "msg" => "Email já cadastrado"]);
    exit;
}

// ATUALIZADO: VEND- + 7 dígitos
$unique_id = "VEND-" . rand(1000000, 9999999);
$senha_hash = password_hash($senha, PASSWORD_DEFAULT);

$stmt = $conn->prepare("INSERT INTO vendedores (unique_id, nome, email, senha_hash) VALUES (?, ?, ?, ?)");
$stmt->bind_param("ssss", $unique_id, $nome, $email, $senha_hash);

if ($stmt->execute()) {
    echo json_encode(["status" => "sucesso", "id" => $unique_id, "nome" => $nome]);
} else {
    echo json_encode(["status" => "erro", "msg" => "Erro ao cadastrar"]);
}
$conn->close();
?>