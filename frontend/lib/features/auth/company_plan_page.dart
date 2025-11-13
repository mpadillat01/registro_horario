import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/services/auth_service.dart';

class CompanyPlansPage extends StatefulWidget {
  const CompanyPlansPage({super.key});

  @override
  State<CompanyPlansPage> createState() => _CompanyPlansPageState();
}

class _CompanyPlansPageState extends State<CompanyPlansPage>
    with SingleTickerProviderStateMixin {
  int selected = 1;

  Future<void> _continue() async {
    final planName = switch (selected) {
      0 => "starter",
      1 => "pro",
      2 => "enterprise",
      _ => "pro",
    };

    try {
      await AuthService.setCompanyPlan(planName);
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.registerCompany);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> plans = [
      {
        "title": "Starter",
        "subtitle": "Ideal para pequeños equipos",
        "price": "4,95 €/mes",
        "color": const Color(0xFF4ADE80),
        "gradient": const [Color(0xFFa2facf), Color(0xFF64acff)],
        "features": [
          "Hasta 3 empleados",
          "Reportes básicos",
          "Soporte por email",
        ],
      },
      {
        "title": "Pro",
        "subtitle": "El más popular",
        "price": "14,99 €/mes",
        "color": const Color(0xFF2563EB),
        "gradient": const [Color(0xFF667EEA), Color(0xFF764BA2)],
        "features": [
          "Hasta 25 empleados",
          "Reportes avanzados",
          "Soporte prioritario",
          "Integración con apps externas",
        ],
      },
      {
        "title": "Enterprise",
        "subtitle": "Para grandes empresas",
        "price": "39,99 €/mes",
        "color": const Color(0xFFF59E0B),
        "gradient": const [Color(0xFFFFD86F), Color(0xFFFBB03B)],
        "features": [
          "Empleados ilimitados",
          "Dashboard personalizado",
          "Integraciones premium",
          "Soporte 24/7 dedicado",
        ],
      },
    ];

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1117) : const Color(0xFFF3F5FB),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Text(
                "Planes disponibles",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Compara y elige el que mejor se adapte a tu empresa",
                style: TextStyle(
                  fontSize: 15,
                  color: dark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 55),

              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = constraints.maxWidth < 1000 ? 20.0 : 30.0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(plans.length, (i) {
                      final p = plans[i];
                      final bool selectedCard = selected == i;
                      final Color color = p["color"] as Color;
                      final List<Color> gradient =
                          (p["gradient"] as List<Color>?) ?? [color, color];

                      return GestureDetector(
                        onTap: () => setState(() => selected = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                          width: 280,
                          height: 410,
                          transform: Matrix4.identity()
                            ..scale(selectedCard ? 1.07 : 1.0),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF1B1E25).withOpacity(0.8)
                                : Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selectedCard
                                  ? color.withOpacity(0.8)
                                  : Colors.transparent,
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: selectedCard
                                    ? color.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.08),
                                blurRadius: selectedCard ? 35 : 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            children: [
                              if (dark)
                                BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    color: Colors.white.withOpacity(0.02),
                                  ),
                                ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 90,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                p["title"] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                p["subtitle"] as String,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selectedCard)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Precio mensual",
                                            style: TextStyle(
                                              color: dark
                                                  ? Colors.white70
                                                  : Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            p["price"] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                              color: dark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Divider(
                                            color: dark
                                                ? Colors.white10
                                                : Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 10),
                                          for (final f
                                              in (p["features"]
                                                  as List<String>))
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: color,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      f,
                                                      style: TextStyle(
                                                        color: dark
                                                            ? Colors.white70
                                                            : Colors
                                                                  .grey
                                                                  .shade800,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),

              const SizedBox(height: 60),

              Container(
                width: 220,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: selected == 0
                        ? const [Color(0xFF4ADE80), Color(0xFF22C55E)]
                        : selected == 1
                        ? const [Color(0xFF3B82F6), Color(0xFF1E3A8A)]
                        : const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Continuar",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
