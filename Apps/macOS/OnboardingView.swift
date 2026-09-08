import SwiftUI

/// Prompt compacto exibido no lugar da agenda quando ainda não há acesso ao
/// calendário. O Kanban continua utilizável ao lado.
struct AgendaPermissionPrompt: View {
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(hex: "7C5CFF"))

            Text("Conecte sua agenda")
                .font(.system(size: 15, weight: .semibold))

            Text("""
            A agenda e o espelho de tarefas usam o calendário do sistema. \
            Autorize o acesso; se a conta Google ainda não estiver no Mac, \
            adicione em Ajustes → Contas de Internet → Google (marque Calendários).
            """)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button("Autorizar calendário") { retry() }
                .buttonStyle(.borderedProminent)

            Text("Também dá para autorizar em Ajustes → Privacidade e Segurança → Calendários → Norte.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.ultraThinMaterial)
    }
}
