package com.vprofile.account.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Self-healing Database Initializer for Cloud-Native / Containerized Environments.
 * Automatically checks whether the required database schema ('user' table) exists.
 * If absent, executes 'accountsdb.sql' to seed roles and the administrative account.
 */
@Component
public class DatabaseInitializer implements InitializingBean {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseInitializer.class);

    @Autowired
    private DataSource dataSource;

    @Override
    public void afterPropertiesSet() {
        initializeDatabaseIfRequired();
    }

    public void initializeDatabaseIfRequired() {
        logger.info("Verifying database connectivity and schema readiness...");
        try (Connection connection = dataSource.getConnection()) {
            boolean tableExists = false;
            try (Statement statement = connection.createStatement()) {
                try (ResultSet rs = statement.executeQuery("SELECT count(*) FROM user")) {
                    if (rs.next()) {
                        tableExists = true;
                        logger.info("Database schema validated: 'user' table exists with {} records.", rs.getInt(1));
                    }
                }
            } catch (Exception e) {
                // Table does not exist or needs seeding
                logger.info("'user' table not found. Proceeding with automated schema initialization.");
            }

            if (!tableExists) {
                logger.info("Executing automated database seeding from accountsdb.sql...");
                ResourceDatabasePopulator populator = new ResourceDatabasePopulator();
                populator.setIgnoreFailedDrops(true);
                populator.setContinueOnError(true);
                populator.addScript(new ClassPathResource("accountsdb.sql"));
                populator.execute(dataSource);
                logger.info("Automated database schema and seed data successfully initialized.");
            }
        } catch (Exception ex) {
            logger.warn("Database initialization skipped or database unreachable at boot: {}", ex.getMessage());
        }
    }
}
