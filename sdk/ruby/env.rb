# frozen_string_literal: true

# Carregador mínimo de .env para os exemplos.
#
# Lê o .env da raiz do repositório e popula ENV com o que ainda não estiver
# definido — variáveis reais do ambiente sempre vencem.
#
# Em produção você não precisa disso: exporte as variáveis e a SDK as lê sozinha.

require "api_brasil"

module Exemplos
  CAMINHO_ENV = File.expand_path("../../.env", __dir__)

  # Popula ENV a partir do .env da raiz, sem sobrescrever o ambiente.
  def self.carregar_env
    return unless File.readable?(CAMINHO_ENV)

    File.readlines(CAMINHO_ENV, chomp: true).each do |linha|
      linha = linha.strip
      next if linha.empty? || linha.start_with?("#") || !linha.include?("=")

      chave, valor = linha.split("=", 2)
      chave = chave.strip
      valor = valor.to_s.strip.gsub(/\A["']|["']\z/, "")

      ENV[chave] = valor if !chave.empty? && !valor.empty? && ENV[chave].nil?
    end
  end

  # Encerra o exemplo se uma credencial obrigatória estiver faltando.
  def self.exigir(chave, dica = nil)
    valor = ENV[chave]
    return valor unless valor.nil? || valor.empty?

    warn "Defina #{chave} no .env da raiz do repositório."
    warn dica if dica
    exit 1
  end
end

Exemplos.carregar_env
