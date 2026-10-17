# Manutenção de touch no Ubuntu

Protótipo para Ubuntu 20.04/Focal e 22.04/Jammy, x86_64, com sessão gráfica, sudo e virtualização habilitada. Ainda requer teste em totem de bancada. Não grava firmware nem inicia a VM automaticamente.

## Publicação

Coloque install.sh em um repositório de sua organização. Hospede a OVA em armazenamento HTTPS controlado ou em um Release privado com um método de autenticação adequado. Não coloque Windows, firmware ou ferramentas proprietárias em repositório público sem direitos de distribuição. O script atual recebe uma URL HTTPS acessível pelo wget; autenticação de Git privado não está implementada.

Calcule o SHA256 da OVA final, depois de preparar/testar o Windows. Use esse valor no comando distribuído. O hash deve vir de uma origem confiável.

```bash
wget -O install-touch.sh 'https://raw.githubusercontent.com/willianberejuk/firmware-touch/main/install.sh'
# Revise o script antes de executá-lo.
bash install-touch.sh 'https://SEU_HOST/7SN_x64.ova' 'SHA256_DA_OVA'
```

Execute como o usuário que utilizará a sessão gráfica. O script pede sudo somente para operações de sistema. Não execute a chamada principal com sudo.

## Extension Pack

O instalador usa os pacotes Ubuntu disponíveis para cada distribuição, sem forçar pacotes Jammy em Focal. A disponibilidade depende dos repositórios configurados. Não fixa uma versão antiga do VirtualBox nem instala silenciosamente o Extension Pack.

Se o script parar nessa etapa, confira o direito de uso empresarial e instale um Extension Pack da mesma versão do VirtualBox. O pacote `virtualbox-ext-pack` é um downloader e sua versão disponível deve corresponder à instalação. Havendo licença/autorização aplicável, a instalação interativa pode ser feita com `sudo apt install virtualbox-ext-pack`; leia os termos apresentados. Alternativamente use o gerenciador do VirtualBox com o pacote correspondente. Execute o script novamente depois.

Referências: https://www.virtualbox.org/wiki/Downloads e https://packages.ubuntu.com/jammy/virtualbox-ext-pack

## O que será alterado

- Instala dependências e VirtualBox pelos repositórios Ubuntu; habilita universe/multiverse.
- Adiciona o usuário a vboxusers; exige nova sessão para USB.
- Importa a OVA como Touch-Manutencao, se esse nome não estiver registrado.
- Exige VM desligada; na primeira importação redefine somente seus filtros USB, removendo os antigos, inclusive Gertec. Reexecuções preservam filtros adicionados depois.
- Configura eGalax 0eef:c002 e 0eef:79fd sem restringir a revisão do firmware.
- Mantém 1 CPU/1 GB de RAM e desabilita a rede da VM de manutenção.
- Cria atalho no menu de aplicativos. Não altera o programa de atendimento do totem.

Reserve espaço para OVA, disco importado e crescimento do disco, além dos programas. A OVA original tem disco virtual de apenas 1,8 GiB: conferir espaço interno antes de adicionar ferramentas. Reexecutar reaplica os recursos da VM dedicada, preservando os filtros existentes. Não use esse nome para outra máquina.

## Validação obrigatória em bancada

1. Importar uma cópia da OVA e confirmar que o Windows inicia; preservar o original.
2. Conferir ferramentas existentes. Copiar o pacote completo do eGalax e o ILITEK, junto dos firmwares aprovados para cada modelo. Isso ainda não foi feito nesta OVA.
3. Confirmar que ambos abrem e reconhecem os controladores. A arquitetura de 32 bits dos executáveis, isoladamente, não prova compatibilidade.
4. Identificar ILITEK com `lsusb` e `VBoxManage list usbhost`; registrar VID/PID normal e de bootloader, se houver. Adicionar filtros específicos pelo VirtualBox com a VM desligada.
5. Capturar somente o touch pretendido. O Ubuntu perde o uso desse touch enquanto a VM o controla; ter teclado/mouse de manutenção.
6. Testar reconhecimento e transição para bootloader antes de validar uma gravação com o procedimento do fabricante. Snapshot não restaura firmware físico.
7. Se módulos não carregarem, verificar DKMS e assinatura/MOK de Secure Boot. Não desabilitar Secure Boot automaticamente.
8. Após homologação, desligar e exportar uma OVA final; recalcular o SHA256 e testar em um Focal e um Jammy antes de distribuir.

O conteúdo do disco e o funcionamento USB não foram validados. A inspeção da configuração declara Windows 7 SP1 x64; a configuração não comprova integridade do Windows nem dos programas instalados. A rede foi desativada como padrão do ambiente legado de manutenção.
