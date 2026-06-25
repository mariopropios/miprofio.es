import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/company_card.dart';
import '../../../../shared/widgets/responsive_layout.dart';

class CompaniesListScreen extends ConsumerWidget {
  const CompaniesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const params = ProfessionalSearchParams(limit: 24);
    final professionalsAsync = ref.watch(professionalsProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('Profesionales')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(professionalsProvider(params));
          await ref.read(professionalsProvider(params).future);
        },
        child: ResponsiveContent(
          child: AsyncValueWidget<List<Company>>(
            value: professionalsAsync,
            loadingMessage: 'Cargando profesionales...',
            empty: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No hay profesionales registrados')),
              ],
            ),
            data: (companies) => GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.isMobile(context)
                    ? 1
                    : ResponsiveLayout.isTablet(context)
                        ? 2
                        : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                    ResponsiveLayout.isMobile(context) ? 1.22 : 0.78,
              ),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                return CompanyCard(
                  company: company,
                  onTap: () => context.push(
                    AppRoutes.companyDetailPath(company.id),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
